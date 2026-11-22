import CoreAudio
import Foundation

/// Tells Notchpad when any app starts or stops using the default microphone.
/// Event-driven (CoreAudio listeners), no polling. Notchpad never opens the mic itself,
/// so no permission is needed.
@MainActor
final class MicMonitor {
    var onChange: ((Bool) -> Void)?
    private var device = AudioDeviceID(0)
    private var watched: Set<AudioDeviceID> = []

    func start() {
        var addr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultInputDevice,
                                              mScope: kAudioObjectPropertyScopeGlobal,
                                              mElement: kAudioObjectPropertyElementMain)
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &addr, .main) { [weak self] _, _ in
            MainActor.assumeIsolated { self?.followDefaultDevice() }
        }
        followDefaultDevice()
    }

    /// Watch whichever device is the default input now (it changes when AirPods connect).
    private func followDefaultDevice() {
        device = Self.defaultInputDevice()
        if device != 0, !watched.contains(device) {
            watched.insert(device)
            var addr = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
                                                  mScope: kAudioObjectPropertyScopeGlobal,
                                                  mElement: kAudioObjectPropertyElementMain)
            AudioObjectAddPropertyListenerBlock(device, &addr, .main) { [weak self] _, _ in
                MainActor.assumeIsolated { self?.report() }
            }
        }
        report()
    }

    private func report() {
        onChange?(device != 0 && Self.isRunning(device))
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
