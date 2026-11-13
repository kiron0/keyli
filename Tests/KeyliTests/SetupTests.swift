import Testing
import Foundation
@testable import Keyli

@Suite("First-Run Setup Tests", .serialized)
struct SetupTests {
    private func freshDefaults() -> UserDefaults {
        let name = "keyli.setup.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test("A fresh install starts setup at Welcome")
    func freshInstallStartsAtWelcome() {
        #expect(SetupStep.resume(accessibilityGranted: false, completed: false, saved: 0) == .welcome)
    }

    @Test("Setup resumes where the user left off, such as after a relaunch")
    func resumesSavedStep() {
        #expect(SetupStep.resume(accessibilityGranted: true, completed: false, saved: SetupStep.inputMonitoring.rawValue) == .inputMonitoring)
        #expect(SetupStep.resume(accessibilityGranted: true, completed: false, saved: SetupStep.loginItem.rawValue) == .loginItem)
    }

    @Test("Missing Accessibility always sends the user back to the required step")
    func missingAccessibilityReturnsToRequiredStep() {
        #expect(SetupStep.resume(accessibilityGranted: false, completed: false, saved: SetupStep.loginItem.rawValue) == .accessibility)
        #expect(SetupStep.resume(accessibilityGranted: false, completed: true, saved: 0) == .accessibility)
    }

    @Test("Completed setup with Accessibility granted does not show again")
    func completedSetupStaysHidden() {
        #expect(SetupStep.resume(accessibilityGranted: true, completed: true, saved: 0) == nil)
    }

    @Test("The Typing step blocks Continue until Accessibility is allowed")
    func accessibilityGatesContinue() {
        let model = SetupAssistantModel(step: .accessibility, defaults: freshDefaults())
        #expect(!model.canAdvance(accessibilityGranted: false))
        #expect(model.canAdvance(accessibilityGranted: true))
        model.step = .inputMonitoring
        #expect(model.canAdvance(accessibilityGranted: false))
    }

    @Test("Steps advance in order, save progress, and finishing clears it")
    func stepsAdvanceAndPersist() {
        let defaults = freshDefaults()
        let model = SetupAssistantModel(step: .welcome, defaults: defaults)
        var visited: [SetupStep] = [model.step]
        for _ in 0..<SetupStep.allCases.count {
            model.next()
            if visited.last != model.step { visited.append(model.step) }
        }
        #expect(visited == SetupStep.allCases)
        #expect(defaults.integer(forKey: SetupAssistantModel.stepKey) == SetupStep.done.rawValue)
        model.back()
        #expect(model.step == .loginItem)

        #expect(!SetupAssistantModel.isCompleted(defaults))
        model.markCompleted()
        #expect(SetupAssistantModel.isCompleted(defaults))
        #expect(defaults.object(forKey: SetupAssistantModel.stepKey) == nil)
    }
}
