import Foundation

struct DirectTRMNLSyncService {
    private let healthKitStore = HealthKitStore()
    private let client = DirectTRMNLClient()

    func sync() async throws -> HealthSnapshot {
        let configuration = AppConfigurationStore.load()
        guard
            let webhookValue = KeychainStore.load(.trmnlWebhookURL),
            let webhookURL = webhookValue.normalizedURL,
            webhookURL.isTRMNLPrivatePluginWebhookURL
        else {
            throw AppModelError.missingTRMNLWebhookURL
        }

        let snapshot = try await healthKitStore.fetchDailySnapshot(
            deviceName: configuration.deviceName
        )
        try await client.updateSnapshot(webhookURL: webhookURL, snapshot: snapshot)

        var updatedConfiguration = configuration
        updatedConfiguration.lastSuccessfulSync = .now
        try AppConfigurationStore.save(updatedConfiguration)
        return snapshot
    }
}
