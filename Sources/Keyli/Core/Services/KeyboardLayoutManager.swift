import Foundation
import AppKit

public final class KeyboardLayoutManager: ObservableObject {
    public static let shared = KeyboardLayoutManager()

    private var inputSourceObserver: NSObjectProtocol?
    private var distributedInputSourceObserver: NSObjectProtocol?

    private init() {
        startObservingInputSource()
    }

    deinit {
        if let observer = inputSourceObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = distributedInputSourceObserver {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
    }

    public func startObservingInputSource() {
        guard inputSourceObserver == nil else { return }

        inputSourceObserver = NotificationCenter.default.addObserver(
            forName: NSTextInputContext.keyboardSelectionDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.scheduleReload()
        }

        distributedInputSourceObserver = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.apple.Carbon.TISNotifySelectedKeyboardInputSourceChanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.scheduleReload()
        }
    }

    private var reloadScheduled = false

    private func scheduleReload() {
        guard !reloadScheduled else { return }
        reloadScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.reloadScheduled = false
            self.reloadActiveLayout()
        }
    }

    public func reloadActiveLayout() {
        let geometry = GeometryType(rawValue: ConfigStore.shared.config.layoutGeometry) ?? .ansi
        let layout = generateLayout(geometry: geometry)
        if KeyboardState.shared.currentLayout != layout {
            KeyboardState.shared.currentLayout = layout
        }
    }

    public func generateLayout(geometry: GeometryType) -> KeyboardLayout {
        CharacterTranslator.shared.refreshInputSource()
        let translator = CharacterTranslator.shared

        let keys: [KeyboardKey]
        let width: Double = 15.0
        let height: Double

        switch geometry {
        case .ansi:
            height = 6.5
            keys = buildANSIKeys(translator: translator)
        case .iso:
            height = 6.5
            keys = buildISOKeys(translator: translator)
        case .jis:
            height = 6.5
            keys = buildJISKeys(translator: translator)
        case .compact:
            height = 5.5
            keys = buildCompactKeys(translator: translator)
        }

        return KeyboardLayout(
            id: "\(geometry.rawValue)_\(translator.activeInputSourceID)",
            name: "\(geometry.displayName) (\(translator.activeInputSourceName))",
            geometryType: geometry,
            inputSourceId: translator.activeInputSourceID,
            inputSourceName: translator.activeInputSourceName,
            unitWidth: width,
            unitHeight: height,
            keys: keys
        )
    }

    private func buildANSIKeys(translator: CharacterTranslator) -> [KeyboardKey] {
        var list: [KeyboardKey] = []

        let fh: Double = 0.75
        list.append(KeyboardKey(id: "k_esc",  keyCode: 53,  kind: .system,   unitFrame: KeyUnitFrame(x: 0.0,   y: 0, width: 1.5,   height: fh), labels: KeyLabels(defaultLabel: "esc")))

        let fStart: Double = 1.5
        let fW: Double = 1.0
        let fCodes: [(UInt16, String, String?, KeySystemAction?)] = [
            (122, "F1", "sun.min.fill", .brightnessDown), (120, "F2", "sun.max.fill", .brightnessUp),
            (99,  "F3", "rectangle.3.group", .missionControl), (118, "F4", "magnifyingglass", .spotlight),
            (96,  "F5", "mic.fill", nil), (97,  "F6", "moon.fill", nil),
            (98,  "F7", "backward.fill", .previousTrack), (100, "F8", "playpause.fill", .playPause),
            (101, "F9", "forward.fill", .nextTrack), (109, "F10", "speaker.slash.fill", .mute),
            (103, "F11", "speaker.wave.1.fill", .volumeDown), (111, "F12", "speaker.wave.3.fill", .volumeUp)
        ]
        for (i, (code, label, icon, action)) in fCodes.enumerated() {
            let x = fStart + Double(i) * fW
            list.append(KeyboardKey(id: "k_\(code)", keyCode: code, kind: .function,
                unitFrame: KeyUnitFrame(x: x, y: 0, width: fW, height: fh),
                labels: KeyLabels(defaultLabel: label), symbolIcon: icon, systemAction: action))
        }
        list.append(KeyboardKey(id: "k_lock", keyCode: KeyliConstants.noKeyCode, kind: .system,
            unitFrame: KeyUnitFrame(x: fStart + 12 * fW, y: 0, width: 1.5, height: fh),
            labels: KeyLabels(defaultLabel: "lock"), symbolIcon: "lock.fill", systemAction: .lockScreen))

        let ny: Double = 0.85
        let nh: Double = 1.0
        let numCodes: [UInt16] = [50, 18, 19, 20, 21, 23, 22, 26, 28, 25, 29, 27, 24]
        for (i, code) in numCodes.enumerated() {
            let labels = translator.translateKeycode(code)
            list.append(KeyboardKey(id: "k_\(code)", keyCode: code, kind: .character,
                unitFrame: KeyUnitFrame(x: Double(i), y: ny, width: 1.0, height: nh),
                labels: labels))
        }
        list.append(KeyboardKey(id: "k_delete", keyCode: 51, kind: .system,
            unitFrame: KeyUnitFrame(x: 13.0, y: ny, width: 2.0, height: nh),
            labels: KeyLabels(defaultLabel: "delete"), symbolIcon: "delete.left.fill"))

        let qy: Double = 1.95
        let qh: Double = 1.0
        list.append(KeyboardKey(id: "k_tab", keyCode: 48, kind: .system,
            unitFrame: KeyUnitFrame(x: 0.0, y: qy, width: 1.5, height: qh),
            labels: KeyLabels(defaultLabel: "tab"), symbolIcon: "arrow.right.to.line.compact"))
        let qCodes: [UInt16] = [12, 13, 14, 15, 17, 16, 32, 34, 31, 35, 33, 30]
        for (i, code) in qCodes.enumerated() {
            let labels = translator.translateKeycode(code)
            list.append(KeyboardKey(id: "k_\(code)", keyCode: code, kind: .character,
                unitFrame: KeyUnitFrame(x: 1.5 + Double(i), y: qy, width: 1.0, height: qh),
                labels: labels))
        }
        let bslashLabels = translator.translateKeycode(42)
        list.append(KeyboardKey(id: "k_42", keyCode: 42, kind: .character,
            unitFrame: KeyUnitFrame(x: 13.5, y: qy, width: 1.5, height: qh),
            labels: bslashLabels))

        let hy: Double = 3.05
        let hh: Double = 1.0
        list.append(KeyboardKey(id: "k_caps", keyCode: 57, kind: .modifier, modifierType: .capsLock,
            unitFrame: KeyUnitFrame(x: 0.0, y: hy, width: 1.75, height: hh),
            labels: KeyLabels(defaultLabel: "caps lock"), symbolIcon: "capslock.fill"))
        let hCodes: [UInt16] = [0, 1, 2, 3, 5, 4, 38, 40, 37, 41, 39]
        for (i, code) in hCodes.enumerated() {
            let labels = translator.translateKeycode(code)
            list.append(KeyboardKey(id: "k_\(code)", keyCode: code, kind: .character,
                unitFrame: KeyUnitFrame(x: 1.75 + Double(i), y: hy, width: 1.0, height: hh),
                labels: labels))
        }
        list.append(KeyboardKey(id: "k_return", keyCode: 36, kind: .system,
            unitFrame: KeyUnitFrame(x: 12.75, y: hy, width: 2.25, height: hh),
            labels: KeyLabels(defaultLabel: "return"), symbolIcon: "return"))

        let sy: Double = 4.15
        let sh: Double = 1.0
        list.append(KeyboardKey(id: "k_lshift", keyCode: 56, kind: .modifier, modifierType: .shift,
            unitFrame: KeyUnitFrame(x: 0.0, y: sy, width: 2.25, height: sh),
            labels: KeyLabels(defaultLabel: "shift"), symbolIcon: "shift.fill"))
        let sCodes: [UInt16] = [6, 7, 8, 9, 11, 45, 46, 43, 47, 44]
        for (i, code) in sCodes.enumerated() {
            let labels = translator.translateKeycode(code)
            list.append(KeyboardKey(id: "k_\(code)", keyCode: code, kind: .character,
                unitFrame: KeyUnitFrame(x: 2.25 + Double(i), y: sy, width: 1.0, height: sh),
                labels: labels))
        }
        list.append(KeyboardKey(id: "k_rshift", keyCode: 60, kind: .modifier, modifierType: .shift,
            unitFrame: KeyUnitFrame(x: 12.25, y: sy, width: 2.75, height: sh),
            labels: KeyLabels(defaultLabel: "shift"), symbolIcon: "shift.fill"))

        let my: Double = 5.25
        let mh: Double = 1.0
        let ah: Double = 0.5
        let aw: Double = 0.875

        list.append(KeyboardKey(id: "k_fn",    keyCode: 63,  kind: .modifier, modifierType: .fn,
            unitFrame: KeyUnitFrame(x: 0.0,   y: my, width: 1.0,  height: mh),
            labels: KeyLabels(defaultLabel: "fn"), symbolIcon: "globe"))
        list.append(KeyboardKey(id: "k_lctrl", keyCode: 59,  kind: .modifier, modifierType: .control,
            unitFrame: KeyUnitFrame(x: 1.0,   y: my, width: 1.25, height: mh),
            labels: KeyLabels(defaultLabel: "control"), symbolIcon: "control"))
        list.append(KeyboardKey(id: "k_lopt",  keyCode: 58,  kind: .modifier, modifierType: .option,
            unitFrame: KeyUnitFrame(x: 2.25,  y: my, width: 1.25, height: mh),
            labels: KeyLabels(defaultLabel: "option"), symbolIcon: "option"))
        list.append(KeyboardKey(id: "k_lcmd",  keyCode: 55,  kind: .modifier, modifierType: .command,
            unitFrame: KeyUnitFrame(x: 3.5,   y: my, width: 1.5,  height: mh),
            labels: KeyLabels(defaultLabel: "command"), symbolIcon: "command"))

        list.append(KeyboardKey(id: "k_space", keyCode: 49, kind: .character,
            unitFrame: KeyUnitFrame(x: 5.0, y: my, width: 4.625, height: mh),
            labels: KeyLabels(defaultLabel: " ")))

        list.append(KeyboardKey(id: "k_rcmd",  keyCode: 54,  kind: .modifier, modifierType: .command,
            unitFrame: KeyUnitFrame(x: 9.625, y: my, width: 1.5,  height: mh),
            labels: KeyLabels(defaultLabel: "command"), symbolIcon: "command"))
        list.append(KeyboardKey(id: "k_ropt",  keyCode: 61,  kind: .modifier, modifierType: .option,
            unitFrame: KeyUnitFrame(x: 11.125, y: my, width: 1.25, height: mh),
            labels: KeyLabels(defaultLabel: "option"), symbolIcon: "option"))

        let arrowX: Double = 12.375
        list.append(KeyboardKey(id: "k_larrow", keyCode: 123, kind: .navigation,
            unitFrame: KeyUnitFrame(x: arrowX,        y: my + ah, width: aw, height: ah),
            labels: KeyLabels(defaultLabel: "◀"), symbolIcon: "arrowtriangle.backward.fill"))
        list.append(KeyboardKey(id: "k_uarrow", keyCode: 126, kind: .navigation,
            unitFrame: KeyUnitFrame(x: arrowX + aw,   y: my,      width: aw, height: ah),
            labels: KeyLabels(defaultLabel: "▲"), symbolIcon: "arrowtriangle.up.fill"))
        list.append(KeyboardKey(id: "k_darrow", keyCode: 125, kind: .navigation,
            unitFrame: KeyUnitFrame(x: arrowX + aw,   y: my + ah, width: aw, height: ah),
            labels: KeyLabels(defaultLabel: "▼"), symbolIcon: "arrowtriangle.down.fill"))
        list.append(KeyboardKey(id: "k_rarrow", keyCode: 124, kind: .navigation,
            unitFrame: KeyUnitFrame(x: arrowX + aw * 2, y: my + ah, width: aw, height: ah),
            labels: KeyLabels(defaultLabel: "▶"), symbolIcon: "arrowtriangle.forward.fill"))

        return list
    }

    private func buildISOKeys(translator: CharacterTranslator) -> [KeyboardKey] {
        var list = buildANSIKeys(translator: translator)
        let topLeft = list.first { $0.id == "k_50" }?.unitFrame ?? KeyUnitFrame(x: 0, y: 0.85)
        list.removeAll { ["k_50", "k_lshift", "k_42", "k_return"].contains($0.id) }
        list.append(KeyboardKey(id: "k_10", keyCode: 10, kind: .character,
            unitFrame: topLeft, labels: translator.translateKeycode(10)))
        list.append(KeyboardKey(id: "k_42", keyCode: 42, kind: .character,
            unitFrame: KeyUnitFrame(x: 12.75, y: 3.05, width: 1.0, height: 1.0),
            labels: translator.translateKeycode(42)))
        list.append(KeyboardKey(id: "k_return", keyCode: 36, kind: .system,
            unitFrame: KeyUnitFrame(x: 13.75, y: 1.95, width: 1.25, height: 2.1),
            labels: KeyLabels(defaultLabel: "return"), symbolIcon: "return",
            topLeftExtension: 0.25))
        list.append(KeyboardKey(id: "k_lshift", keyCode: 56, kind: .modifier, modifierType: .shift,
            unitFrame: KeyUnitFrame(x: 0.0, y: 4.15, width: 1.25, height: 1.0),
            labels: KeyLabels(defaultLabel: "shift"), symbolIcon: "shift.fill"))
        list.append(KeyboardKey(id: "k_50", keyCode: 50, kind: .character,
            unitFrame: KeyUnitFrame(x: 1.25, y: 4.15, width: 1.0, height: 1.0),
            labels: translator.translateKeycode(50)))
        return list
    }

    private func buildJISKeys(translator: CharacterTranslator) -> [KeyboardKey] {
        var list = buildANSIKeys(translator: translator)
        list.removeAll { ["k_50", "k_space", "k_rshift"].contains($0.id) }
        list = list.map { key in
            var k = key
            if k.unitFrame.y == 0.85 && k.kind == .character {
                k.unitFrame.x -= 1.0
            }
            return k
        }
        list.append(KeyboardKey(id: "k_93", keyCode: 93, kind: .character,
            unitFrame: KeyUnitFrame(x: 12.0, y: 0.85, width: 1.0, height: 1.0),
            labels: translator.translateKeycode(93)))
        list.append(KeyboardKey(id: "k_94", keyCode: 94, kind: .character,
            unitFrame: KeyUnitFrame(x: 12.25, y: 4.15, width: 1.0, height: 1.0),
            labels: translator.translateKeycode(94)))
        list.append(KeyboardKey(id: "k_rshift", keyCode: 60, kind: .modifier, modifierType: .shift,
            unitFrame: KeyUnitFrame(x: 13.25, y: 4.15, width: 1.75, height: 1.0),
            labels: KeyLabels(defaultLabel: "shift"), symbolIcon: "shift.fill"))
        list.append(KeyboardKey(id: "k_eisu", keyCode: 102, kind: .system,
            unitFrame: KeyUnitFrame(x: 5.0, y: 5.25, width: 1.125, height: 1.0),
            labels: KeyLabels(defaultLabel: "英数")))
        list.append(KeyboardKey(id: "k_space", keyCode: 49, kind: .character,
            unitFrame: KeyUnitFrame(x: 6.125, y: 5.25, width: 2.375, height: 1.0),
            labels: KeyLabels(defaultLabel: " ")))
        list.append(KeyboardKey(id: "k_kana", keyCode: 104, kind: .system,
            unitFrame: KeyUnitFrame(x: 8.5, y: 5.25, width: 1.125, height: 1.0),
            labels: KeyLabels(defaultLabel: "かな")))
        return list
    }

    private func buildCompactKeys(translator: CharacterTranslator) -> [KeyboardKey] {
        var ansi = buildANSIKeys(translator: translator)
        ansi.removeAll { $0.unitFrame.y < 0.85 }
        return ansi.map { key in
            var k = key
            k.unitFrame.y -= 0.85
            return k
        }
    }
}
