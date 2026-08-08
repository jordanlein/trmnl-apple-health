import Foundation
import HealthKit

enum DestinationSyncOutcome {
    case directTRMNLPush
    case homeAssistantUpdate
    case selfHostedBridgePush
    case selfHostedBridgeStore
    case selfHostedBridgeMissingWebhook

    var statusSuffix: String? {
        switch self {
        case .directTRMNLPush, .selfHostedBridgePush:
            return "pushed"
        case .homeAssistantUpdate:
            return nil
        case .selfHostedBridgeStore:
            return "stored"
        case .selfHostedBridgeMissingWebhook:
            return "webhook not configured"
        }
    }

    var dialogLabel: String {
        switch self {
        case .directTRMNLPush:
            return "TRMNL Direct"
        case .homeAssistantUpdate:
            return "Home Assistant"
        case .selfHostedBridgePush, .selfHostedBridgeStore, .selfHostedBridgeMissingWebhook:
            return "Self-Hosted Bridge"
        }
    }
}

enum HealthSnapshotSource: String, Equatable {
    case fresh
    case cached
}

struct DestinationSyncResult {
    let snapshot: HealthSnapshot
    let outcome: DestinationSyncOutcome
    let snapshotSource: HealthSnapshotSource

    func statusMessage(reason: String) -> String {
        let formattedDate = snapshot.capturedAt.formatted(date: .omitted, time: .shortened)
        let sourceSuffix = snapshotSource == .cached ? ", cached health data" : ""
        guard let statusSuffix = outcome.statusSuffix else {
            return "Last sync: \(formattedDate) (\(reason)\(sourceSuffix))"
        }
        return "Last sync: \(formattedDate) (\(reason), \(statusSuffix)\(sourceSuffix))"
    }
}

struct DestinationSyncService {
    private let healthKitStore = HealthKitStore()
    private let directTRMNLClient = DirectTRMNLClient()
    private let homeAssistantClient = HomeAssistantClient()
    private let selfHostedBridgeClient = SelfHostedBridgeClient()

    func sync(
        registerHomeAssistantSensors: Bool = false,
        allowsCachedHealthSnapshot: Bool = false
    ) async throws -> DestinationSyncResult {
        var configuration = AppConfigurationStore.load()
        let snapshotResult = try await healthSnapshot(
            configuration: configuration,
            allowsCachedHealthSnapshot: allowsCachedHealthSnapshot
        )
        let snapshot = snapshotResult.snapshot

        let outcome: DestinationSyncOutcome
        switch configuration.syncDestination {
        case .directTRMNL:
            guard
                let webhookValue = KeychainStore.load(.trmnlWebhookURL),
                let webhookURL = webhookValue.normalizedURL,
                webhookURL.isTRMNLPrivatePluginWebhookURL
            else {
                throw AppModelError.missingTRMNLWebhookURL
            }

            try await directTRMNLClient.updateSnapshot(
                webhookURL: webhookURL,
                snapshot: snapshot,
                snapshotSource: snapshotResult.source
            )
            outcome = .directTRMNLPush

        case .homeAssistant:
            guard configuration.registration != nil else {
                throw AppModelError.missingRegistration
            }

            if registerHomeAssistantSensors {
                try await homeAssistantClient.registerSensors(
                    configuration: configuration,
                    snapshot: snapshot
                )
            }

            try await homeAssistantClient.updateSensors(
                configuration: configuration,
                snapshot: snapshot
            )
            outcome = .homeAssistantUpdate

        case .selfHostedBridge:
            guard
                configuration.bridgeRegistration != nil,
                let bridgeURL = configuration.bridgeURL,
                let deviceToken = KeychainStore.load(.selfHostedDeviceToken),
                !deviceToken.isEmpty
            else {
                throw AppModelError.missingBridgeRegistration
            }

            let response = try await selfHostedBridgeClient.updateSnapshot(
                serverURL: bridgeURL,
                deviceToken: deviceToken,
                snapshot: snapshot,
                trmnlWebhookURL: configuration.trmnlWebhookURLString
            )

            if response.trmnlWebhookConfigured,
               !response.pushedToTRMNL,
               let pushError = response.trmnlPushError,
               !pushError.isEmpty {
                throw AppModelError.trmnlPushFailed(pushError)
            } else if !response.trmnlWebhookConfigured {
                outcome = .selfHostedBridgeMissingWebhook
            } else if response.pushedToTRMNL {
                outcome = .selfHostedBridgePush
            } else {
                outcome = .selfHostedBridgeStore
            }
        }

        configuration.lastSuccessfulSync = .now
        configuration.lastSnapshot = snapshot
        try AppConfigurationStore.save(configuration)
        return DestinationSyncResult(
            snapshot: snapshot,
            outcome: outcome,
            snapshotSource: snapshotResult.source
        )
    }

    private func healthSnapshot(
        configuration: AppConfiguration,
        allowsCachedHealthSnapshot: Bool
    ) async throws -> (snapshot: HealthSnapshot, source: HealthSnapshotSource) {
        do {
            let snapshot = try await healthKitStore.fetchDailySnapshot(
                deviceName: configuration.deviceName
            )
            var updatedConfiguration = configuration
            updatedConfiguration.lastSnapshot = snapshot
            try? AppConfigurationStore.save(updatedConfiguration)
            return (snapshot, .fresh)
        } catch {
            guard
                allowsCachedHealthSnapshot,
                Self.isHealthDatabaseInaccessible(error),
                let cachedSnapshot = configuration.lastSnapshot
            else {
                throw error
            }
            return (cachedSnapshot, .cached)
        }
    }

    private static func isHealthDatabaseInaccessible(_ error: Error) -> Bool {
        guard let healthKitError = error as? HKError else {
            return false
        }
        return healthKitError.code == .errorDatabaseInaccessible
    }
}
