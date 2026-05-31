import AppIntents

struct SyncHealthRingsToTRMNLIntent: AppIntent {
    static let title: LocalizedStringResource = "Sync Apple Health to TRMNL"
    static let description = IntentDescription(
        "Send today's Apple Health dashboard snapshot using your configured destination."
    )
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let result = try await DestinationSyncService().sync()
        let snapshot = result.snapshot
        return .result(
            dialog: "Synced Apple Health via \(result.outcome.dialogLabel): Move \(snapshot.movePercent)%, Exercise \(snapshot.exercisePercent)%, Stand \(snapshot.standPercent)%."
        )
    }
}

struct TRMNLHealthShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SyncHealthRingsToTRMNLIntent(),
            phrases: [
                "Sync Apple Health with \(.applicationName)",
                "Refresh my TRMNL health dashboard with \(.applicationName)",
            ],
            shortTitle: "Sync Apple Health",
            systemImageName: "heart.circle"
        )
    }
}
