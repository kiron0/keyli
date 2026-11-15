import Testing
import Foundation
@testable import Keyli

@Suite("Auto Show")
struct AutoShowTests {
    @Test func detectsEditableTextInputs() {
        #expect(AutoShowService.isTextInput(role: "AXTextField", subrole: nil, editable: true))
        #expect(AutoShowService.isTextInput(role: "AXTextArea", subrole: nil, editable: nil))
        #expect(AutoShowService.isTextInput(role: "AXComboBox", subrole: nil, editable: true))
        #expect(!AutoShowService.isTextInput(role: "AXTextField", subrole: "AXSecureTextField", editable: true))
        #expect(!AutoShowService.isTextInput(role: "AXSecureTextField", subrole: nil, editable: true))
        #expect(!AutoShowService.isTextInput(role: "AXTextArea", subrole: nil, editable: false))
        #expect(!AutoShowService.isTextInput(role: "AXButton", subrole: nil, editable: false))
        #expect(!AutoShowService.isTextInput(role: nil, subrole: nil, editable: true))
    }

    @Test func respectsSettingsVisibilityAndExclusions() {
        #expect(AutoShowService.shouldShow(enabled: true, isText: true, bundleId: "com.apple.TextEdit", excluded: [], keyboardVisible: false))
        #expect(!AutoShowService.shouldShow(enabled: false, isText: true, bundleId: "com.apple.TextEdit", excluded: [], keyboardVisible: false))
        #expect(!AutoShowService.shouldShow(enabled: true, isText: true, bundleId: "com.apple.TextEdit", excluded: ["com.apple.TextEdit"], keyboardVisible: false))
        #expect(!AutoShowService.shouldShow(enabled: true, isText: true, bundleId: "a", excluded: [], keyboardVisible: true))
        #expect(!AutoShowService.shouldShow(enabled: true, isText: false, bundleId: "a", excluded: [], keyboardVisible: false))
        let config = KeyliConfig()
        #expect(!config.autoShowKeyboard && config.autoHideKeyboard && config.autoShowExcludedApps.isEmpty)
    }
}
