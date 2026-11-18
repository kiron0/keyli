import Foundation
import AppKit

public enum KeyTap {
    public static func perform(_ key: KeyboardKey, state: KeyboardState = .shared) {
        KeySoundEngine.shared.tap(key.keyCode)
        state.virtualPressedKeyId = key.id
        if key.modifierType == .fn {
            KeyboardInputDispatcher.shared.handleGlobeTap(state: state)
        } else {
            KeyboardInputDispatcher.shared.dispatchKey(key, state: state)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            if state.virtualPressedKeyId == key.id {
                state.virtualPressedKeyId = nil
            }
        }
    }
}
