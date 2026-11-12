import Foundation
import AudioToolbox
import AppKit

public final class SoundService {
    public static let shared = SoundService()

    private init() {}

    public func playKeyClick() {
        guard ConfigStore.shared.config.playKeyClickSound else { return }
        // System Sound ID 1104 is the standard macOS typing click sound
        AudioServicesPlaySystemSound(1104)
    }

    public func playModifierClick() {
        guard ConfigStore.shared.config.playKeyClickSound else { return }
        // System Sound ID 1105 is the subtle modifier toggle sound
        AudioServicesPlaySystemSound(1105)
    }
}
