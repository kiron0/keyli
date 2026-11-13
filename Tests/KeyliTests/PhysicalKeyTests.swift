import Testing
import Foundation
import AppKit
import Carbon
@testable import Keyli

@Suite("Physical Keyboard Matches On-Screen Keys", .serialized)
struct PhysicalKeyTests {
    static let ansiPhysicalKeys: [String: Int] = [
        "k_esc": kVK_Escape,
        "k_122": kVK_F1, "k_120": kVK_F2, "k_99": kVK_F3, "k_118": kVK_F4,
        "k_96": kVK_F5, "k_97": kVK_F6, "k_98": kVK_F7, "k_100": kVK_F8,
        "k_101": kVK_F9, "k_109": kVK_F10, "k_103": kVK_F11, "k_111": kVK_F12,
        "k_50": kVK_ANSI_Grave,
        "k_18": kVK_ANSI_1, "k_19": kVK_ANSI_2, "k_20": kVK_ANSI_3, "k_21": kVK_ANSI_4,
        "k_23": kVK_ANSI_5, "k_22": kVK_ANSI_6, "k_26": kVK_ANSI_7, "k_28": kVK_ANSI_8,
        "k_25": kVK_ANSI_9, "k_29": kVK_ANSI_0, "k_27": kVK_ANSI_Minus, "k_24": kVK_ANSI_Equal,
        "k_delete": kVK_Delete,
        "k_tab": kVK_Tab,
        "k_12": kVK_ANSI_Q, "k_13": kVK_ANSI_W, "k_14": kVK_ANSI_E, "k_15": kVK_ANSI_R,
        "k_17": kVK_ANSI_T, "k_16": kVK_ANSI_Y, "k_32": kVK_ANSI_U, "k_34": kVK_ANSI_I,
        "k_31": kVK_ANSI_O, "k_35": kVK_ANSI_P, "k_33": kVK_ANSI_LeftBracket, "k_30": kVK_ANSI_RightBracket,
        "k_42": kVK_ANSI_Backslash,
        "k_caps": kVK_CapsLock,
        "k_0": kVK_ANSI_A, "k_1": kVK_ANSI_S, "k_2": kVK_ANSI_D, "k_3": kVK_ANSI_F,
        "k_5": kVK_ANSI_G, "k_4": kVK_ANSI_H, "k_38": kVK_ANSI_J, "k_40": kVK_ANSI_K,
        "k_37": kVK_ANSI_L, "k_41": kVK_ANSI_Semicolon, "k_39": kVK_ANSI_Quote,
        "k_return": kVK_Return,
        "k_lshift": kVK_Shift,
        "k_6": kVK_ANSI_Z, "k_7": kVK_ANSI_X, "k_8": kVK_ANSI_C, "k_9": kVK_ANSI_V,
        "k_11": kVK_ANSI_B, "k_45": kVK_ANSI_N, "k_46": kVK_ANSI_M, "k_43": kVK_ANSI_Comma,
        "k_47": kVK_ANSI_Period, "k_44": kVK_ANSI_Slash,
        "k_rshift": kVK_RightShift,
        "k_fn": kVK_Function, "k_lctrl": kVK_Control, "k_lopt": kVK_Option, "k_lcmd": kVK_Command,
        "k_space": kVK_Space,
        "k_rcmd": kVK_RightCommand, "k_ropt": kVK_RightOption,
        "k_larrow": kVK_LeftArrow, "k_uarrow": kVK_UpArrow, "k_darrow": kVK_DownArrow, "k_rarrow": kVK_RightArrow
    ]

    static let rowOrder: [[Int]] = [
        [kVK_ANSI_Grave, kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4, kVK_ANSI_5, kVK_ANSI_6, kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9, kVK_ANSI_0, kVK_ANSI_Minus, kVK_ANSI_Equal, kVK_Delete],
        [kVK_Tab, kVK_ANSI_Q, kVK_ANSI_W, kVK_ANSI_E, kVK_ANSI_R, kVK_ANSI_T, kVK_ANSI_Y, kVK_ANSI_U, kVK_ANSI_I, kVK_ANSI_O, kVK_ANSI_P, kVK_ANSI_LeftBracket, kVK_ANSI_RightBracket, kVK_ANSI_Backslash],
        [kVK_CapsLock, kVK_ANSI_A, kVK_ANSI_S, kVK_ANSI_D, kVK_ANSI_F, kVK_ANSI_G, kVK_ANSI_H, kVK_ANSI_J, kVK_ANSI_K, kVK_ANSI_L, kVK_ANSI_Semicolon, kVK_ANSI_Quote, kVK_Return],
        [kVK_Shift, kVK_ANSI_Z, kVK_ANSI_X, kVK_ANSI_C, kVK_ANSI_V, kVK_ANSI_B, kVK_ANSI_N, kVK_ANSI_M, kVK_ANSI_Comma, kVK_ANSI_Period, kVK_ANSI_Slash, kVK_RightShift]
    ]

    private func state(for geometry: GeometryType) -> KeyboardState {
        let state = KeyboardState()
        state.currentLayout = KeyboardLayoutManager.shared.generateLayout(geometry: geometry)
        return state
    }

    private func keyEvent(_ code: Int, down: Bool) -> CGEvent {
        CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(code), keyDown: down)!
    }

    private func flagsEvent(_ code: Int, flags: CGEventFlags) -> CGEvent {
        let event = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(code), keyDown: true)!
        event.type = .flagsChanged
        event.flags = flags
        return event
    }

    private func mediaEvent(_ keyType: Int, down: Bool) -> CGEvent {
        let data1 = (keyType << 16) | ((down ? 0x0A : 0x0B) << 8)
        return NSEvent.otherEvent(
            with: .systemDefined,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            subtype: 8,
            data1: data1,
            data2: -1
        )!.cgEvent!
    }

    private func send(_ event: CGEvent, to state: KeyboardState) {
        PhysicalKeyboardMonitor.shared.handleCGEvent(type: event.type, event: event, state: state)
    }

    private func litKeyIds(_ state: KeyboardState) -> Set<String> {
        Set(state.currentLayout.keys.filter { state.pressedPhysicalKeyCodes.contains($0.keyCode) }.map(\.id))
    }

    @Test("Every on-screen ANSI key carries the macOS virtual key code of the same physical key")
    func everyAnsiKeyMatchesHardware() {
        let layout = KeyboardLayoutManager.shared.generateLayout(geometry: .ansi)
        let pressable = layout.keys.filter { $0.keyCode != KeyliConstants.noKeyCode }
        #expect(pressable.count == Self.ansiPhysicalKeys.count)
        for key in pressable {
            #expect(Self.ansiPhysicalKeys[key.id].map { UInt16($0) } == key.keyCode, "\(key.id) has \(key.keyCode)")
        }
    }

    @Test("ANSI rows run left to right in the same order as the physical keyboard")
    func ansiRowOrderMatchesHardware() {
        let layout = KeyboardLayoutManager.shared.generateLayout(geometry: .ansi)
        for row in Self.rowOrder {
            let keys = row.compactMap { code in layout.keys.first { $0.keyCode == UInt16(code) } }
            #expect(keys.count == row.count)
            let ys = Set(keys.map { $0.unitFrame.y })
            #expect(ys.count == 1)
            let xs = keys.map { $0.unitFrame.x }
            #expect(xs == xs.sorted())
        }
    }

    @Test("Pressing each physical key lights exactly its on-screen key, releasing clears it")
    func eachPhysicalKeyLightsItsKey() {
        for geometry in GeometryType.allCases {
            let state = state(for: geometry)
            for key in state.currentLayout.keys where key.kind != .modifier && key.keyCode != KeyliConstants.noKeyCode {
                send(keyEvent(Int(key.keyCode), down: true), to: state)
                #expect(litKeyIds(state) == [key.id], "\(geometry.rawValue) \(key.id)")
                send(keyEvent(Int(key.keyCode), down: false), to: state)
                #expect(state.pressedPhysicalKeyCodes.isEmpty, "\(geometry.rawValue) \(key.id) stuck")
            }
        }
    }

    @Test("Left and right modifiers light only the side that is held")
    func modifiersLightTheirOwnSide() {
        let state = state(for: .ansi)
        let leftShift = CGEventFlags(rawValue: CGEventFlags.maskShift.rawValue | 0x2)
        let bothShift = CGEventFlags(rawValue: CGEventFlags.maskShift.rawValue | 0x2 | 0x4)
        let rightShift = CGEventFlags(rawValue: CGEventFlags.maskShift.rawValue | 0x4)

        send(flagsEvent(kVK_Shift, flags: leftShift), to: state)
        #expect(litKeyIds(state) == ["k_lshift"])
        send(flagsEvent(kVK_RightShift, flags: bothShift), to: state)
        #expect(litKeyIds(state) == ["k_lshift", "k_rshift"])
        send(flagsEvent(kVK_Shift, flags: rightShift), to: state)
        #expect(litKeyIds(state) == ["k_rshift"])
        send(flagsEvent(kVK_RightShift, flags: []), to: state)
        #expect(litKeyIds(state).isEmpty)

        let cases: [(Int, UInt64, CGEventFlags, String)] = [
            (kVK_Control, 0x1, .maskControl, "k_lctrl"),
            (kVK_Option, 0x20, .maskAlternate, "k_lopt"),
            (kVK_RightOption, 0x40, .maskAlternate, "k_ropt"),
            (kVK_Command, 0x8, .maskCommand, "k_lcmd"),
            (kVK_RightCommand, 0x10, .maskCommand, "k_rcmd"),
            (kVK_Function, 0, .maskSecondaryFn, "k_fn"),
            (kVK_CapsLock, 0, .maskAlphaShift, "k_caps")
        ]
        for (code, device, generic, id) in cases {
            send(flagsEvent(code, flags: CGEventFlags(rawValue: generic.rawValue | device)), to: state)
            #expect(litKeyIds(state) == [id], "\(id) down")
            send(flagsEvent(code, flags: []), to: state)
            #expect(litKeyIds(state).isEmpty, "\(id) up")
        }

        send(flagsEvent(kVK_RightControl, flags: CGEventFlags(rawValue: CGEventFlags.maskControl.rawValue | 0x2000)), to: state)
        #expect(litKeyIds(state) == ["k_lctrl"])
        send(flagsEvent(kVK_RightControl, flags: []), to: state)
        #expect(litKeyIds(state).isEmpty)
    }

    @Test("Brightness, media and volume keys light F1 to F12")
    func mediaKeysLightFunctionRow() {
        let state = state(for: .ansi)
        let expected: [(Int, String)] = [
            (3, "k_122"), (2, "k_120"), (18, "k_98"), (16, "k_100"),
            (17, "k_101"), (7, "k_109"), (1, "k_103"), (0, "k_111"),
            (22, "k_96"), (21, "k_97")
        ]
        for (keyType, id) in expected {
            send(mediaEvent(keyType, down: true), to: state)
            #expect(litKeyIds(state) == [id], "media \(keyType)")
            send(mediaEvent(keyType, down: false), to: state)
            #expect(litKeyIds(state).isEmpty, "media \(keyType) stuck")
        }
    }

    @Test("Mission Control, Spotlight, Dictation and Focus keys light F3 to F6")
    func specialFunctionKeysLightFunctionRow() {
        let state = state(for: .ansi)
        for (code, id) in [(160, "k_99"), (131, "k_118"), (177, "k_118"), (176, "k_96"), (178, "k_97")] {
            send(keyEvent(code, down: true), to: state)
            #expect(litKeyIds(state) == [id], "code \(code)")
            send(keyEvent(code, down: false), to: state)
            #expect(litKeyIds(state).isEmpty)
        }
    }

    @Test("fn combinations and keypad keys light the key that produced them")
    func aliasedKeysLightTheirKey() {
        let state = state(for: .ansi)
        let expected: [(Int, String)] = [
            (kVK_Home, "k_larrow"), (kVK_End, "k_rarrow"), (kVK_PageUp, "k_uarrow"), (kVK_PageDown, "k_darrow"),
            (kVK_ForwardDelete, "k_delete"), (kVK_ANSI_KeypadEnter, "k_return"),
            (kVK_ANSI_Keypad1, "k_18"), (kVK_ANSI_Keypad0, "k_29"), (kVK_ANSI_KeypadMinus, "k_27")
        ]
        for (code, id) in expected {
            send(keyEvent(code, down: true), to: state)
            #expect(litKeyIds(state) == [id], "code \(code)")
            send(keyEvent(code, down: false), to: state)
            #expect(litKeyIds(state).isEmpty)
        }
    }

    @Test("Keys Keyli types itself never light as physical presses")
    func syntheticEventsAreIgnored() {
        let state = state(for: .ansi)
        let event = keyEvent(kVK_ANSI_A, down: true)
        event.setIntegerValueField(.eventSourceUserData, value: KeyliConstants.syntheticEventUserData)
        send(event, to: state)
        #expect(state.pressedPhysicalKeyCodes.isEmpty)
    }

    @Test("ISO keyboards put § top-left and ` beside left shift, like Apple hardware")
    func isoSectionAndGraveSit() {
        let layout = KeyboardLayoutManager.shared.generateLayout(geometry: .iso)
        let section = layout.keys.first { $0.keyCode == UInt16(kVK_ISO_Section) }
        let grave = layout.keys.first { $0.keyCode == UInt16(kVK_ANSI_Grave) }
        let lshift = layout.keys.first { $0.id == "k_lshift" }
        let one = layout.keys.first { $0.keyCode == UInt16(kVK_ANSI_1) }
        #expect(section?.unitFrame.x == 0 && section?.unitFrame.y == one?.unitFrame.y)
        #expect(grave?.unitFrame.y == lshift?.unitFrame.y)
        #expect(grave?.unitFrame.x == (lshift?.unitFrame.x ?? 0) + (lshift?.unitFrame.width ?? 0))
        #expect(layout.keys.first { $0.id == "k_return" }?.unitFrame.height ?? 0 > 2)
    }

    @Test("JIS keyboards include the yen and underscore keys")
    func jisExtraKeys() {
        let codes = Set(KeyboardLayoutManager.shared.generateLayout(geometry: .jis).keys.map(\.keyCode))
        #expect(codes.contains(UInt16(kVK_JIS_Yen)))
        #expect(codes.contains(UInt16(kVK_JIS_Underscore)))
        #expect(codes.contains(UInt16(kVK_JIS_Eisu)))
        #expect(codes.contains(UInt16(kVK_JIS_Kana)))
        #expect(!codes.contains(UInt16(kVK_ANSI_Grave)))
    }

    @Test("US input source labels match what each physical key types")
    func usLabelsMatchTyping() throws {
        let layout = KeyboardLayoutManager.shared.generateLayout(geometry: .ansi)
        try #require(layout.inputSourceId == "com.apple.keylayout.US" || layout.inputSourceId == "com.apple.keylayout.ABC")
        let expected: [Int: (String, String)] = [
            kVK_ANSI_Grave: ("`", "~"), kVK_ANSI_1: ("1", "!"), kVK_ANSI_2: ("2", "@"), kVK_ANSI_3: ("3", "#"),
            kVK_ANSI_4: ("4", "$"), kVK_ANSI_5: ("5", "%"), kVK_ANSI_6: ("6", "^"), kVK_ANSI_7: ("7", "&"),
            kVK_ANSI_8: ("8", "*"), kVK_ANSI_9: ("9", "("), kVK_ANSI_0: ("0", ")"), kVK_ANSI_Minus: ("-", "_"),
            kVK_ANSI_Equal: ("=", "+"), kVK_ANSI_LeftBracket: ("[", "{"), kVK_ANSI_RightBracket: ("]", "}"),
            kVK_ANSI_Backslash: ("\\", "|"), kVK_ANSI_Semicolon: (";", ":"), kVK_ANSI_Quote: ("'", "\""),
            kVK_ANSI_Comma: (",", "<"), kVK_ANSI_Period: (".", ">"), kVK_ANSI_Slash: ("/", "?"),
            kVK_ANSI_A: ("a", "A"), kVK_ANSI_Q: ("q", "Q"), kVK_ANSI_Z: ("z", "Z"), kVK_ANSI_M: ("m", "M")
        ]
        for (code, (plain, shifted)) in expected {
            let key = try #require(layout.keys.first { $0.keyCode == UInt16(code) })
            #expect(key.displayedLabel(shift: false, option: false) == plain, "code \(code)")
            #expect(key.displayedLabel(shift: true, option: false) == shifted, "code \(code) shift")
        }
    }
}
