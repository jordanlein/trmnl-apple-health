import AppIntents

struct SyncHealthRingsToTRMNLIntent: AppIntent {
    static let title: LocalizedStringResource = "Sync Apple Health to TRMNL"
    static let description = IntentDescription(
        "Send today's Apple Health dashboard snapshot to a TRMNL Private Plugin."
    )
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let snapshot = try await DirectTRMNLSyncService().sync()
        return .result(
            dialog: "Synced Apple Health to TRMNL: Move \(snapshot.movePercent)%, Exercise \(snapshot.exercisePercent)%, Stand \(snapshot.standPercent)%."
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
