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

public struct ScanCursor: Equatable {
    public enum Phase: Equatable {
        case rows(Int)
        case keys(row: Int, index: Int)
    }

    public static let keyCyclesBeforeReturning = 2

    public private(set) var rows: [[String]]
    public private(set) var phase: Phase = .rows(0)
    private var passes = 0

    public init(rows: [[String]]) {
        self.rows = rows.filter { !$0.isEmpty }
    }

    public static func rows(for layout: KeyboardLayout) -> [[String]] {
        let keys = layout.keys.filter { $0.kind != .spacer }
        let grouped = Dictionary(grouping: keys) { key in
            (key.unitFrame.y * 4).rounded() / 4
        }
        return grouped.keys.sorted().map { y in
            grouped[y, default: []]
                .sorted { $0.unitFrame.x == $1.unitFrame.x ? $0.unitFrame.y < $1.unitFrame.y : $0.unitFrame.x < $1.unitFrame.x }
                .map(\.id)
        }
    }

    public var highlighted: [String] {
        switch phase {
        case .rows(let row):
            return rows.indices.contains(row) ? rows[row] : []
        case .keys(let row, let index):
            guard rows.indices.contains(row), rows[row].indices.contains(index) else { return [] }
            return [rows[row][index]]
        }
    }

    public var isScanningKeys: Bool {
        if case .keys = phase { return true }
        return false
    }

    public mutating func step() {
        guard !rows.isEmpty else { return }
        switch phase {
        case .rows(let row):
            phase = .rows((row + 1) % rows.count)
        case .keys(let row, let index):
            let next = index + 1
            if next < rows[row].count {
                phase = .keys(row: row, index: next)
            } else {
                passes += 1
                phase = passes >= Self.keyCyclesBeforeReturning ? .rows(row) : .keys(row: row, index: 0)
            }
        }
    }

    public mutating func select() -> String? {
        guard !rows.isEmpty else { return nil }
        switch phase {
        case .rows(let row):
            passes = 0
            phase = .keys(row: row, index: 0)
            return nil
        case .keys(let row, let index):
            phase = .rows(row)
            passes = 0
            return rows[row].indices.contains(index) ? rows[row][index] : nil
        }
    }

    public mutating func reset() {
        phase = .rows(0)
        passes = 0
    }
}

public final class KeyScanner: ObservableObject {
    public static let shared = KeyScanner()

    @Published public private(set) var highlightedKeyIds: [String] = []
    @Published public private(set) var isScanningKeys = false

    public var isKeyboardVisible = false {
        didSet {
            if oldValue != isKeyboardVisible { applyConfig() }
        }
    }

    private var cursor = ScanCursor(rows: [])
    private var layoutId: String?
    private var timer: Timer?

    private init() {}

    public var isActive: Bool { timer != nil }

    public func applyConfig() {
        let config = ConfigStore.shared.config
        if config.scanningEnabled && isKeyboardVisible {
            start(interval: config.scanInterval)
        } else {
            stop()
        }
    }

    private func start(interval: TimeInterval) {
        timer?.invalidate()
        refreshRowsIfNeeded(force: true)
        publish()
        let timer = Timer(timeInterval: max(0.3, interval), repeats: true) { [weak self] _ in
            self?.advance()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func stop() {
        timer?.invalidate()
        timer = nil
        if !highlightedKeyIds.isEmpty { highlightedKeyIds = [] }
        if isScanningKeys { isScanningKeys = false }
    }

    private func refreshRowsIfNeeded(force: Bool = false) {
        let layout = KeyboardState.shared.currentLayout
        guard force || layout.id != layoutId || cursor.rows != ScanCursor.rows(for: layout) else { return }
        layoutId = layout.id
        cursor = ScanCursor(rows: ScanCursor.rows(for: layout))
    }

    private func advance() {
        refreshRowsIfNeeded()
        cursor.step()
        publish()
    }

    private func restartTimer() {
        guard let timer else { return }
        let interval = timer.timeInterval
        timer.invalidate()
        let next = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.advance()
        }
        RunLoop.main.add(next, forMode: .common)
        self.timer = next
    }

    public func select() {
        guard isActive else { return }
        refreshRowsIfNeeded()
        let pressedId = cursor.select()
        publish()
        restartTimer()
        guard let pressedId,
              let key = KeyboardState.shared.currentLayout.keys.first(where: { $0.id == pressedId }) else {
            KeySoundEngine.shared.tap(49)
            return
        }
        KeyTap.perform(key)
    }

    private func publish() {
        let ids = cursor.highlighted
        if ids != highlightedKeyIds { highlightedKeyIds = ids }
        if cursor.isScanningKeys != isScanningKeys { isScanningKeys = cursor.isScanningKeys }
    }
}
