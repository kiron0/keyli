import Foundation
import AppKit
import CoreAudio
import QuartzCore

public final class KeySoundMuteRules: ObservableObject {
    public static let shared = KeySoundMuteRules()

    @Published public private(set) var microphoneInUse = false

    private var checkedAt: CFTimeInterval = -10
    private var isChecking = false
    private let cacheLifetime: CFTimeInterval = 1
    private let probeQueue = DispatchQueue(label: "io.coreify.keyli.mute.probe", qos: .utility)

    public static func shouldMute(muteDuringCalls: Bool, microphoneInUse: Bool, frontBundleId: String?, mutedApps: [String], enabled: Bool = true) -> Bool {
        guard enabled else { return false }
        if muteDuringCalls && microphoneInUse { return true }
        if let frontBundleId, mutedApps.contains(frontBundleId) { return true }
        return false
    }

    public var isMuted: Bool {
        let config = ConfigStore.shared.config
        guard config.keySoundQuietTimesEnabled else { return false }
        if config.keySoundMuteDuringCalls {
            refreshMicrophoneIfNeeded()
        }
        return Self.shouldMute(
            muteDuringCalls: config.keySoundMuteDuringCalls,
            microphoneInUse: microphoneInUse,
            frontBundleId: NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
            mutedApps: config.keySoundMutedApps,
            enabled: config.keySoundQuietTimesEnabled
        )
    }

    public func refreshMicrophoneIfNeeded(force: Bool = false) {
        let now = CACurrentMediaTime()
        guard !isChecking, force || now - checkedAt > cacheLifetime else { return }
        checkedAt = now
        isChecking = true
        probeQueue.async { [weak self] in
            let inUse = Self.isMicrophoneCaptured()
            DispatchQueue.main.async {
                guard let self else { return }
                self.isChecking = false
                if inUse != self.microphoneInUse {
                    self.microphoneInUse = inUse
                }
            }
        }
    }

    static func isMicrophoneCaptured() -> Bool {
        if #available(macOS 14.2, *) {
            return anyOtherProcessCapturesInput()
        }
        return defaultInputDeviceIsRunning()
    }

    private static func address(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
    }

    @available(macOS 14.2, *)
    private static func anyOtherProcessCapturesInput() -> Bool {
        var listAddress = address(kAudioHardwarePropertyProcessObjectList)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &listAddress, 0, nil, &size) == noErr, size > 0 else {
            return false
        }
        var processes = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &listAddress, 0, nil, &size, &processes) == noErr else {
            return false
        }
        let ownPID = ProcessInfo.processInfo.processIdentifier
        for process in processes {
            var pidAddress = address(kAudioProcessPropertyPID)
            var pid: pid_t = 0
            var pidSize = UInt32(MemoryLayout<pid_t>.size)
            if AudioObjectGetPropertyData(process, &pidAddress, 0, nil, &pidSize, &pid) == noErr, pid == ownPID {
                continue
            }
            var inputAddress = address(kAudioProcessPropertyIsRunningInput)
            var running: UInt32 = 0
            var runningSize = UInt32(MemoryLayout<UInt32>.size)
            if AudioObjectGetPropertyData(process, &inputAddress, 0, nil, &runningSize, &running) == noErr, running != 0 {
                return true
            }
        }
        return false
    }

    private static func defaultDevice(_ selector: AudioObjectPropertySelector) -> AudioDeviceID {
        var deviceAddress = address(selector)
        var device = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &deviceAddress, 0, nil, &size, &device)
        return device
    }

    private static func defaultInputDeviceIsRunning() -> Bool {
        let input = defaultDevice(kAudioHardwarePropertyDefaultInputDevice)
        guard input != 0, input != defaultDevice(kAudioHardwarePropertyDefaultOutputDevice) else { return false }
        var runningAddress = address(kAudioDevicePropertyDeviceIsRunningSomewhere)
        var running: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(input, &runningAddress, 0, nil, &size, &running) == noErr else { return false }
        return running != 0
    }
}
