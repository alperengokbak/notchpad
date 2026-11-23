import CoreAudio
import Foundation
import NotchpadCore

/// Tells Notchpad when any app starts or stops using the default microphone.
/// Event-driven (CoreAudio listeners), no polling. Notchpad never opens the mic itself,
/// so no permission is needed. `stop()` removes every listener (indicator turned off).
@MainActor
final class MicMonitor {
    var onChange: ((Bool) -> Void)?
    private var device = AudioDeviceID(0)
    private var watched: Set<AudioDeviceID> = []
    private var watchedProcesses: Set<AudioObjectID> = []
    /// Every listener added, so `stop()` can remove them all.
    private var listeners: [(object: AudioObjectID, address: AudioObjectPropertyAddress, block: AudioObjectPropertyListenerBlock)] = []

    /// Adds a CoreAudio listener on the main queue and remembers it.
    private func listen(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector, _ handler: @escaping @MainActor () -> Void) {
        var addr = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal,
                                              mElement: kAudioObjectPropertyElementMain)
        let block: AudioObjectPropertyListenerBlock = { _, _ in MainActor.assumeIsolated { handler() } }
        if AudioObjectAddPropertyListenerBlock(object, &addr, .main, block) == noErr {
            listeners.append((object, addr, block))
        }
    }

    /// Removes every listener. Nothing runs until `start()` is called again.
    func stop() {
        for l in listeners {
            var addr = l.address
            AudioObjectRemovePropertyListenerBlock(l.object, &addr, .main, l.block)
        }
        listeners.removeAll()
        watched.removeAll()
        watchedProcesses.removeAll()
        device = 0
    }

    func start() {
        guard listeners.isEmpty else { return }
        let system = AudioObjectID(kAudioObjectSystemObject)
        listen(system, kAudioHardwarePropertyDefaultInputDevice) { [weak self] in self?.followDefaultDevice() }
        if #available(macOS 14.4, *) {
            // Exact answer: which processes are recording. Needed because a duplex device
            // (AirPods, USB headset) "runs" just from playing music.
            listen(system, kAudioHardwarePropertyProcessObjectList) { [weak self] in self?.followProcesses() }
            followProcesses()
        }
        followDefaultDevice()
    }

    @available(macOS 14.4, *)
    private func followProcesses() {
        for process in Self.processObjects() where !watchedProcesses.contains(process) {
            watchedProcesses.insert(process)
            listen(process, kAudioProcessPropertyIsRunningInput) { [weak self] in self?.report() }
        }
        report()
    }

    /// Watch whichever device is the default input now (it changes when AirPods connect).
    private func followDefaultDevice() {
        device = Self.defaultInputDevice()
        if device != 0, !watched.contains(device) {
            watched.insert(device)
            listen(device, kAudioDevicePropertyDeviceIsRunningSomewhere) { [weak self] in self?.report() }
        }
        report()
    }

    private func report() {
        var recording: [Bool]? = nil
        if #available(macOS 14.4, *) { recording = Self.processObjects().map(Self.isRecording) }
        onChange?(MicSignal.inUse(processesRecording: recording, deviceRunning: device != 0 && Self.isRunning(device)))
    }

    @available(macOS 14.4, *)
    private static func processObjects() -> [AudioObjectID] {
        let system = AudioObjectID(kAudioObjectSystemObject)
        var addr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyProcessObjectList,
                                              mScope: kAudioObjectPropertyScopeGlobal,
                                              mElement: kAudioObjectPropertyElementMain)
        var size = UInt32(0)
        guard AudioObjectGetPropertyDataSize(system, &addr, 0, nil, &size) == noErr, size > 0 else { return [] }
        var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(system, &addr, 0, nil, &size, &ids) == noErr else { return [] }
        return ids
    }

    @available(macOS 14.4, *)
    private static func isRecording(_ process: AudioObjectID) -> Bool {
        var value = UInt32(0)
        var size = UInt32(MemoryLayout<UInt32>.size)
        var addr = AudioObjectPropertyAddress(mSelector: kAudioProcessPropertyIsRunningInput,
                                              mScope: kAudioObjectPropertyScopeGlobal,
                                              mElement: kAudioObjectPropertyElementMain)
        return AudioObjectGetPropertyData(process, &addr, 0, nil, &size, &value) == noErr && value != 0
    }

    private static func defaultInputDevice() -> AudioDeviceID {
        var id = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var addr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultInputDevice,
                                              mScope: kAudioObjectPropertyScopeGlobal,
                                              mElement: kAudioObjectPropertyElementMain)
        let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &id)
        return status == noErr ? id : 0
    }

    private static func isRunning(_ device: AudioDeviceID) -> Bool {
        var running = UInt32(0)
        var size = UInt32(MemoryLayout<UInt32>.size)
        var addr = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
                                              mScope: kAudioObjectPropertyScopeGlobal,
                                              mElement: kAudioObjectPropertyElementMain)
        return AudioObjectGetPropertyData(device, &addr, 0, nil, &size, &running) == noErr && running != 0
    }
}
