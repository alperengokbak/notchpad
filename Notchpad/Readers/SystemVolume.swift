import AudioToolbox
import CoreAudio
import Foundation
import NotchpadCore

/// The Mac's output volume and mute, read and set through the public CoreAudio API
/// (no permission needed). Listens only between `start()` and `stop()`: while a Music
/// widget is on screen, so a key press or Control Center change shows up in the bar at once.
@MainActor
final class SystemVolume {
    var onChange: ((VolumeLevel) -> Void)?
    private var device = AudioDeviceID(0)
    private var listeners: [(object: AudioObjectID, address: AudioObjectPropertyAddress, block: AudioObjectPropertyListenerBlock)] = []

    var isRunning: Bool { !listeners.isEmpty }

    func start() {
        guard listeners.isEmpty else { return }
        listen(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyDefaultOutputDevice,
               scope: kAudioObjectPropertyScopeGlobal) { [weak self] in self?.followDefaultDevice() }
        followDefaultDevice()
    }

    /// Removes every listener. Nothing runs until `start()` is called again.
    func stop() {
        for l in listeners {
            var addr = l.address
            AudioObjectRemovePropertyListenerBlock(l.object, &addr, .main, l.block)
        }
        listeners.removeAll()
        device = 0
    }

    /// Reads the current level of the default output.
    func read() -> VolumeLevel {
        let id = device != 0 ? device : Self.defaultOutputDevice()
        guard id != 0, let volume = Self.getFloat(id, Self.volumeSelector) else { return .unavailable }
        let settable = Self.isSettable(id, Self.volumeSelector)
        let muted = (Self.getUInt(id, kAudioDevicePropertyMute) ?? 0) != 0
        return VolumeLevel(volume: Double(volume), muted: muted, settable: settable)
    }

    /// Sets volume and mute together. Outputs without a mute switch get volume 0 instead.
    func set(_ level: VolumeLevel) {
        let id = device != 0 ? device : Self.defaultOutputDevice()
        guard id != 0, level.settable else { return }
        if Self.isSettable(id, kAudioDevicePropertyMute) {
            Self.setFloat(id, Self.volumeSelector, Float32(level.volume))
            Self.setUInt(id, kAudioDevicePropertyMute, level.muted ? 1 : 0)
        } else {
            // No mute switch: muting turns the volume down to 0; the speaker click brings it back at a quarter.
            Self.setFloat(id, Self.volumeSelector, level.muted ? 0 : Float32(level.volume))
        }
    }

    // MARK: Listening

    /// Watch whichever device is the default output now (it changes when AirPods connect).
    private func followDefaultDevice() {
        let newDevice = Self.defaultOutputDevice()
        if newDevice != device {
            removeDeviceListeners()
            device = newDevice
            if device != 0 {
                listen(device, Self.volumeSelector, scope: kAudioDevicePropertyScopeOutput) { [weak self] in self?.report() }
                listen(device, kAudioDevicePropertyMute, scope: kAudioDevicePropertyScopeOutput) { [weak self] in self?.report() }
            }
        }
        report()
    }

    private func report() { onChange?(read()) }

    private func listen(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector, scope: AudioObjectPropertyScope,
                        _ handler: @escaping @MainActor () -> Void) {
        var addr = AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
        guard AudioObjectHasProperty(object, &addr) else { return }
        let block: AudioObjectPropertyListenerBlock = { _, _ in MainActor.assumeIsolated { handler() } }
        if AudioObjectAddPropertyListenerBlock(object, &addr, .main, block) == noErr {
            listeners.append((object, addr, block))
        }
    }

    private func removeDeviceListeners() {
        let system = AudioObjectID(kAudioObjectSystemObject)
        listeners.removeAll { l in
            guard l.object != system else { return false }
            var addr = l.address
            AudioObjectRemovePropertyListenerBlock(l.object, &addr, .main, l.block)
            return true
        }
    }

    // MARK: CoreAudio helpers

    /// The volume macOS itself shows: one value for all channels, kept in balance.
    private static let volumeSelector = kAudioHardwareServiceDeviceProperty_VirtualMainVolume

    private static func address(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioDevicePropertyScopeOutput,
                                   mElement: kAudioObjectPropertyElementMain)
    }

    private static func defaultOutputDevice() -> AudioDeviceID {
        var id = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var addr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                                              mScope: kAudioObjectPropertyScopeGlobal,
                                              mElement: kAudioObjectPropertyElementMain)
        let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &id)
        return status == noErr ? id : 0
    }

    private static func isSettable(_ id: AudioDeviceID, _ selector: AudioObjectPropertySelector) -> Bool {
        var addr = address(selector)
        guard AudioObjectHasProperty(id, &addr) else { return false }
        var settable = DarwinBoolean(false)
        return AudioObjectIsPropertySettable(id, &addr, &settable) == noErr && settable.boolValue
    }

    private static func getFloat(_ id: AudioDeviceID, _ selector: AudioObjectPropertySelector) -> Float32? {
        var addr = address(selector)
        guard AudioObjectHasProperty(id, &addr) else { return nil }
        var value = Float32(0)
        var size = UInt32(MemoryLayout<Float32>.size)
        return AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &value) == noErr ? value : nil
    }

    private static func getUInt(_ id: AudioDeviceID, _ selector: AudioObjectPropertySelector) -> UInt32? {
        var addr = address(selector)
        guard AudioObjectHasProperty(id, &addr) else { return nil }
        var value = UInt32(0)
        var size = UInt32(MemoryLayout<UInt32>.size)
        return AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &value) == noErr ? value : nil
    }

    private static func setFloat(_ id: AudioDeviceID, _ selector: AudioObjectPropertySelector, _ value: Float32) {
        var addr = address(selector)
        var v = min(max(value, 0), 1)
        AudioObjectSetPropertyData(id, &addr, 0, nil, UInt32(MemoryLayout<Float32>.size), &v)
    }

    private static func setUInt(_ id: AudioDeviceID, _ selector: AudioObjectPropertySelector, _ value: UInt32) {
        var addr = address(selector)
        var v = value
        AudioObjectSetPropertyData(id, &addr, 0, nil, UInt32(MemoryLayout<UInt32>.size), &v)
    }
}
