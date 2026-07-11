import Foundation

enum AppTaskOnboardingStep: Int, Codable {
    case measure10s = 0
    case visitFiles = 1
    case completed = 2
}

nonisolated enum AppOnboardingStore {
    private static let hasCompletedKey = "onboarding.app.completed"
    private static let currentStepKey = "onboarding.app.currentStep"
    private static let measureProgressKey = "onboarding.app.measureProgress"
    private static let hasSavedMeasureReportKey = "onboarding.app.hasSavedMeasureReport"

    static let measureTargetSeconds: TimeInterval = 10

    static var hasCompletedOnboarding: Bool {
        UserDefaults.standard.bool(forKey: hasCompletedKey)
            || currentStep == .completed
    }

    static var currentStep: AppTaskOnboardingStep {
        let raw = UserDefaults.standard.integer(forKey: currentStepKey)
        return AppTaskOnboardingStep(rawValue: raw) ?? .measure10s
    }

    static var measureProgressSeconds: TimeInterval {
        UserDefaults.standard.double(forKey: measureProgressKey)
    }

    static var showsTaskBanner: Bool {
        !hasCompletedOnboarding && currentStep != .completed
    }

    static func noteMonitoringElapsed(_ elapsed: TimeInterval, isMonitoring: Bool) -> Bool {
        guard !hasCompletedOnboarding else { return false }
        guard currentStep == .measure10s, isMonitoring else { return false }

        let previous = measureProgressSeconds
        let clamped = min(measureTargetSeconds, max(previous, elapsed))
        UserDefaults.standard.set(clamped, forKey: measureProgressKey)

        guard clamped >= measureTargetSeconds, previous < measureTargetSeconds else {
            return false
        }

        advanceToVisitFiles()
        return !hasSavedMeasureReport
    }

    static var hasSavedMeasureReport: Bool {
        UserDefaults.standard.bool(forKey: hasSavedMeasureReportKey)
    }

    static func markMeasureReportSaved() {
        UserDefaults.standard.set(true, forKey: hasSavedMeasureReportKey)
    }

    static func noteFilesTabVisited() {
        guard !hasCompletedOnboarding else { return }
        guard currentStep == .visitFiles else { return }
        markCompleted()
        AppTelemetry.logProductEvent(
            "onboarding_task_completed",
            parameters: ["task": "visit_files"]
        )
    }

    static func markCompleted() {
        UserDefaults.standard.set(true, forKey: hasCompletedKey)
        UserDefaults.standard.set(AppTaskOnboardingStep.completed.rawValue, forKey: currentStepKey)
    }

    private static func advanceToVisitFiles() {
        UserDefaults.standard.set(AppTaskOnboardingStep.visitFiles.rawValue, forKey: currentStepKey)
        AppTelemetry.logProductEvent(
            "onboarding_task_completed",
            parameters: ["task": "measure_10s"]
        )
        AppTelemetry.logProductEvent(
            "onboarding_step_viewed",
            parameters: ["step": "2"]
        )
    }

    #if DEBUG
    static func resetForTesting() {
        UserDefaults.standard.removeObject(forKey: hasCompletedKey)
        UserDefaults.standard.removeObject(forKey: currentStepKey)
        UserDefaults.standard.removeObject(forKey: measureProgressKey)
        UserDefaults.standard.removeObject(forKey: hasSavedMeasureReportKey)
    }
    #endif
}
