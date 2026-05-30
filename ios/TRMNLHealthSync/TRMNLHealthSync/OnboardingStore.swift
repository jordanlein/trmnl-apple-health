import Foundation

enum OnboardingStore {
    private static let completionKey = "TRMNLHealthSync.onboarding.completed"

    static var hasCompletedOnboarding: Bool {
        UserDefaults.standard.bool(forKey: completionKey)
    }

    static func markCompleted() {
        UserDefaults.standard.set(true, forKey: completionKey)
    }
}
