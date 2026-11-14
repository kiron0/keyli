import Foundation

public enum SoundKeyMap {
    public static let macKeyNames: [UInt16: String] = [
        0: "KeyA", 1: "KeyS", 2: "KeyD", 3: "KeyF", 4: "KeyH", 5: "KeyG", 6: "KeyZ", 7: "KeyX",
        8: "KeyC", 9: "KeyV", 10: "IntlBackslash", 11: "KeyB", 12: "KeyQ", 13: "KeyW", 14: "KeyE",
        15: "KeyR", 16: "KeyY", 17: "KeyT", 18: "Digit1", 19: "Digit2", 20: "Digit3", 21: "Digit4",
        22: "Digit6", 23: "Digit5", 24: "Equal", 25: "Digit9", 26: "Digit7", 27: "Minus", 28: "Digit8",
        29: "Digit0", 30: "BracketRight", 31: "KeyO", 32: "KeyU", 33: "BracketLeft", 34: "KeyI",
        35: "KeyP", 36: "Enter", 37: "KeyL", 38: "KeyJ", 39: "Quote", 40: "KeyK", 41: "Semicolon",
        42: "Backslash", 43: "Comma", 44: "Slash", 45: "KeyN", 46: "KeyM", 47: "Period", 48: "Tab",
        49: "Space", 50: "Backquote", 51: "Backspace", 53: "Escape", 54: "MetaRight", 55: "MetaLeft",
        56: "ShiftLeft", 57: "CapsLock", 58: "AltLeft", 59: "ControlLeft", 60: "ShiftRight",
        61: "AltRight", 62: "ControlRight", 63: "Fn", 64: "F17", 65: "NumpadDecimal",
        67: "NumpadMultiply", 69: "NumpadAdd", 71: "NumLock", 75: "NumpadDivide", 76: "NumpadEnter",
        78: "NumpadSubtract", 79: "F18", 80: "F19", 81: "NumpadEqual", 82: "Numpad0", 83: "Numpad1",
        84: "Numpad2", 85: "Numpad3", 86: "Numpad4", 87: "Numpad5", 88: "Numpad6", 89: "Numpad7",
        90: "F20", 91: "Numpad8", 92: "Numpad9", 93: "IntlYen", 94: "IntlRo", 96: "F5", 97: "F6",
        98: "F7", 99: "F3", 100: "F8", 101: "F9", 103: "F11", 105: "F13", 106: "F16", 107: "F14",
        109: "F10", 110: "ContextMenu", 111: "F12", 113: "F15", 114: "Insert", 115: "Home",
        116: "PageUp", 117: "Delete", 118: "F4", 119: "End", 120: "F2", 121: "PageDown", 122: "F1",
        123: "ArrowLeft", 124: "ArrowRight", 125: "ArrowDown", 126: "ArrowUp", 179: "Fn"
    ]

    public static let legacyCodes: [String: [Int]] = [
        "Escape": [1], "Digit1": [2], "Digit2": [3], "Digit3": [4], "Digit4": [5], "Digit5": [6],
        "Digit6": [7], "Digit7": [8], "Digit8": [9], "Digit9": [10], "Digit0": [11], "Minus": [12],
        "Equal": [13], "Backspace": [14], "Tab": [15], "KeyQ": [16], "KeyW": [17], "KeyE": [18],
        "KeyR": [19], "KeyT": [20], "KeyY": [21], "KeyU": [22], "KeyI": [23], "KeyO": [24],
        "KeyP": [25], "BracketLeft": [26], "BracketRight": [27], "Enter": [28], "ControlLeft": [29],
        "KeyA": [30], "KeyS": [31], "KeyD": [32], "KeyF": [33], "KeyG": [34], "KeyH": [35],
        "KeyJ": [36], "KeyK": [37], "KeyL": [38], "Semicolon": [39], "Quote": [40], "Backquote": [41],
        "ShiftLeft": [42], "Backslash": [43], "KeyZ": [44], "KeyX": [45], "KeyC": [46], "KeyV": [47],
        "KeyB": [48], "KeyN": [49], "KeyM": [50], "Comma": [51], "Period": [52], "Slash": [53],
        "ShiftRight": [54], "NumpadMultiply": [55], "AltLeft": [56], "Space": [57], "CapsLock": [58],
        "F1": [59], "F2": [60], "F3": [61], "F4": [62], "F5": [63], "F6": [64], "F7": [65], "F8": [66],
        "F9": [67], "F10": [68], "NumLock": [69], "ScrollLock": [70], "Numpad7": [71], "Numpad8": [72],
        "Numpad9": [73], "NumpadSubtract": [74], "Numpad4": [75], "Numpad5": [76], "Numpad6": [77],
        "NumpadAdd": [78], "Numpad1": [79], "Numpad2": [80], "Numpad3": [81], "Numpad0": [82],
        "NumpadDecimal": [83], "IntlBackslash": [86], "F11": [87], "F12": [88], "F13": [91],
        "F14": [92], "F15": [93], "F16": [99], "F17": [100], "F18": [101], "F19": [102], "F20": [103],
        "IntlRo": [115], "IntlYen": [125], "NumpadEqual": [3597], "NumpadEnter": [3612],
        "ControlRight": [3613], "NumpadDivide": [3637], "PrintScreen": [3639], "AltRight": [3640],
        "Pause": [3653], "Home": [3655, 60999], "PageUp": [3657, 61001], "End": [3663, 61007],
        "PageDown": [3665, 61009], "Insert": [3666, 61010], "Delete": [3667, 61011],
        "MetaLeft": [3675], "MetaRight": [3676], "ContextMenu": [3677],
        "ArrowUp": [57416, 61000], "ArrowLeft": [57419, 61003], "ArrowRight": [57421, 61005],
        "ArrowDown": [57424, 61008]
    ]

    public static let nameForLegacyCode: [Int: String] = {
        var result: [Int: String] = [:]
        for (name, codes) in legacyCodes {
            for code in codes where result[code] == nil {
                result[code] = name
            }
        }
        return result
    }()

    public static let fallbacks: [String: [String]] = [
        "ShiftRight": ["ShiftLeft"], "ControlRight": ["ControlLeft"], "AltRight": ["AltLeft"],
        "MetaRight": ["MetaLeft"], "MetaLeft": ["AltLeft"], "Fn": ["ControlLeft", "AltLeft"],
        "NumpadEnter": ["Enter"], "Numpad0": ["Digit0"], "Numpad1": ["Digit1"], "Numpad2": ["Digit2"],
        "Numpad3": ["Digit3"], "Numpad4": ["Digit4"], "Numpad5": ["Digit5"], "Numpad6": ["Digit6"],
        "Numpad7": ["Digit7"], "Numpad8": ["Digit8"], "Numpad9": ["Digit9"], "NumpadAdd": ["Equal"],
        "NumpadSubtract": ["Minus"], "NumpadMultiply": ["Digit8"], "NumpadDivide": ["Slash"],
        "NumpadDecimal": ["Period"], "NumpadEqual": ["Equal"], "NumLock": ["Escape"],
        "IntlBackslash": ["Backquote"], "IntlYen": ["Backslash"], "IntlRo": ["Slash"],
        "ContextMenu": ["MetaRight", "AltRight"], "Insert": ["Home"], "Delete": ["Backspace"],
        "Home": ["PageUp"], "End": ["PageDown"], "PageUp": ["Home"], "PageDown": ["End"],
        "F13": ["F12"], "F14": ["F12"], "F15": ["F12"], "F16": ["F12"], "F17": ["F12"],
        "F18": ["F12"], "F19": ["F12"], "F20": ["F12"]
    ]

    public static let genericFallbacks = ["KeyA", "KeyS", "KeyF", "Space"]

    public static func name(forMacKeyCode keyCode: UInt16) -> String? {
        macKeyNames[keyCode]
    }
}
