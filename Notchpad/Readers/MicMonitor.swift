import CoreAudio
import Foundation
import NotchpadCore

/// Tells Notchpad when any app starts or stops using the default microphone.
/// Event-driven (CoreAudio listeners), no polling. Notchpad never opens the mic itself,
/// so no permission is needed.
@MainActor
final class MicMonitor {
    var onChange: ((Bool) -> Void)?
    private var device = AudioDeviceID(0)
    private var watched: Set<AudioDeviceID> = []
    private var watchedProcesses: Set<AudioObjectID> = []

    func start() {
        var addr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultInputDevice,
                                              mScope: kAudioObjectPropertyScopeGlobal,
                                              mElement: kAudioObjectPropertyElementMain)
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &addr, .main) { [weak self] _, _ in
            MainActor.assumeIsolated { self?.followDefaultDevice() }
        }
        if #available(macOS 14.4, *) {
            // Exact answer: which processes are recording. Needed because a duplex device
            // (AirPods, USB headset) "runs" just from playing music.
            var list = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyProcessObjectList,
                                                  mScope: kAudioObjectPropertyScopeGlobal,
                                                  mElement: kAudioObjectPropertyElementMain)
            AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &list, .main) { [weak self] _, _ in
                MainActor.assumeIsolated { self?.followProcesses() }
            }
            followProcesses()
        }
        followDefaultDevice()
    }

    @available(macOS 14.4, *)
    private func followProcesses() {
        for process in Self.processObjects() where !watchedProcesses.contains(process) {
            watchedProcesses.insert(process)
            var addr = AudioObjectPropertyAddress(mSelector: kAudioProcessPropertyIsRunningInput,
                                                  mScope: kAudioObjectPropertyScopeGlobal,
                                                  mElement: kAudioObjectPropertyElementMain)
            AudioObjectAddPropertyListenerBlock(process, &addr, .main) { [weak self] _, _ in
                MainActor.assumeIsolated { self?.report() }
            }
        }
        report()
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
