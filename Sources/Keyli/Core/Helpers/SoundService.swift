import Foundation
import AudioToolbox
import AppKit

public final class SoundService {
    public static let shared = SoundService()

    private init() {}

    public func playKeyClick() {
        guard ConfigStore.shared.config.playKeyClickSound else { return }
        AudioServicesPlaySystemSound(1104)
    }

    public func playModifierClick() {
        guard ConfigStore.shared.config.playKeyClickSound else { return }
        AudioServicesPlaySystemSound(1105)
    }
}
