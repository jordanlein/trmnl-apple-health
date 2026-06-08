import Foundation
import Combine
import HealthKit

@MainActor
final class AppModel: ObservableObject {
    @Published var syncDestinationInput: SyncDestination
    @Published var instanceURLInput: String
    @Published var accessTokenInput: String
    @Published var bridgeURLInput: String
    @Published var bridgeSetupTokenInput: String
    @Published var trmnlWebhookURLInput: String
    @Published var deviceNameInput: String
    @Published var lastSnapshot: HealthSnapshot?
    @Published var statusMessage = "Ready"
    @Published var healthAccessStatusMessage = "Health access has not been checked yet."
    @Published var isBusy = false
    @Published var didFinishInitialLoad = false

    var hasConfiguredDestination: Bool {
        hasSavedRegistration
    }

    private var configuration: AppConfiguration
    private let healthKitStore = HealthKitStore()
    private let homeAssistantClient = HomeAssistantClient()
    private let selfHostedBridgeClient = SelfHostedBridgeClient()
    private let destinationSyncService = DestinationSyncService()
    private var observersInstalled = false
    private var observerSyncTask: Task<Void, Never>?
    private var hasRegisteredSensors = false

    init() {
        let loaded = AppConfigurationStore.load()
        configuration = loaded
        syncDestinationInput = loaded.syncDestination
        instanceURLInput = loaded.instanceURLString
        accessTokenInput = KeychainStore.load(.homeAssistantAccessToken) ?? ""
        bridgeURLInput = loaded.bridgeURLString
        bridgeSetupTokenInput = KeychainStore.load(.selfHostedSetupToken) ?? ""
        trmnlWebhookURLInput =
            KeychainStore.load(.trmnlWebhookURL) ?? loaded.trmnlWebhookURLString
        deviceNameInput = loaded.deviceName
        lastSnapshot = loaded.lastSnapshot
    }

    func bootstrap() async {
        guard !didFinishInitialLoad else { return }
        didFinishInitialLoad = true

        guard hasSavedRegistration else {
            return
        }

        do {
            try await healthKitStore.requestAuthorization()
            await refreshHealthAccessStatus()
            installObserversIfNeeded()
            try await syncNow(reason: "launch")
        } catch {
            statusMessage = error.localizedDescription
            healthAccessStatusMessage = error.localizedDescription
        }
    }

    func handleSceneBecameActive() async {
        guard hasSavedRegistration else { return }
        do {
            try await syncNow(reason: "foreground")
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func connectAndSync() async {
        isBusy = true
        defer { isBusy = false }

        do {
            try await healthKitStore.requestAuthorization()
            await refreshHealthAccessStatus()
            switch syncDestinationInput {
            case .directTRMNL:
                try connectDirectTRMNL()
            case .homeAssistant:
                try await connectHomeAssistant()
            case .selfHostedBridge:
                try await connectSelfHostedBridge()
            }

            installObserversIfNeeded()
            try await syncNow(reason: "setup")
            statusMessage = "Connected and synced."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func refreshHealthAccessStatus() async {
        do {
            let requestStatus = try await healthKitStore.authorizationRequestStatus()
            healthAccessStatusMessage = healthAccessMessage(for: requestStatus)
        } catch {
            healthAccessStatusMessage = error.localizedDescription
        }
    }

    func reviewHealthPermissions() async {
        isBusy = true
        healthAccessStatusMessage = "Asking iOS to review Health permissions..."
        defer { isBusy = false }

        do {
            try await healthKitStore.requestAuthorization()
            await refreshHealthAccessStatus()
            installObserversIfNeeded()
            statusMessage = "Health permissions reviewed."
        } catch {
            statusMessage = error.localizedDescription
            healthAccessStatusMessage = error.localizedDescription
        }
    }

    func checkHealthAccess() async {
        isBusy = true
        healthAccessStatusMessage = "Checking HealthKit locally..."
        defer { isBusy = false }

        do {
            try await healthKitStore.requestAuthorization()
            let readableDataTypes = try await healthKitStore.recentReadableDataTypes()
            let snapshot = try await healthKitStore.fetchDailySnapshot(deviceName: deviceNameInput)
            lastSnapshot = snapshot
            await refreshHealthAccessStatus()
            healthAccessStatusMessage = healthCheckMessage(
                for: snapshot,
                readableDataTypes: readableDataTypes
            )
            statusMessage = "HealthKit check completed locally."
        } catch {
            statusMessage = error.localizedDescription
            healthAccessStatusMessage = error.localizedDescription
        }
    }

    func syncButtonTapped() async {
        isBusy = true
        defer { isBusy = false }

        do {
            try await syncNow(reason: "manual")
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func resetConfiguration() {
        configuration = AppConfiguration()
        syncDestinationInput = .directTRMNL
        instanceURLInput = ""
        accessTokenInput = ""
        bridgeURLInput = ""
        bridgeSetupTokenInput = ""
        trmnlWebhookURLInput = ""
        deviceNameInput = DeviceIdentity.defaultDeviceName
        lastSnapshot = nil
        hasRegisteredSensors = false
        observersInstalled = false
        observerSyncTask?.cancel()
        observerSyncTask = nil
        KeychainStore.clearAll()
        AppConfigurationStore.clear()
        statusMessage = "Cleared local configuration."
        healthAccessStatusMessage = "Health access has not been checked yet."
    }

    func scheduleObserverSync() {
        observerSyncTask?.cancel()
        let delaySeconds = observerSyncDelaySeconds
        observerSyncTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            await self?.syncAfterObserverDelay()
        }
    }

    private func syncAfterObserverDelay() async {
        do {
            try await syncNow(reason: "healthkit")
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func syncNow(reason: String) async throws {
        let shouldRegisterHomeAssistantSensors =
            configuration.syncDestination == .homeAssistant && !hasRegisteredSensors
        let result = try await destinationSyncService.sync(
            registerHomeAssistantSensors: shouldRegisterHomeAssistantSensors
        )

        lastSnapshot = result.snapshot
        configuration = AppConfigurationStore.load()
        if shouldRegisterHomeAssistantSensors {
            hasRegisteredSensors = true
        }
        statusMessage = result.statusMessage(reason: reason)
    }

    private func installObserversIfNeeded() {
        guard !observersInstalled else { return }
        observersInstalled = true
        healthKitStore.installObservers { [weak self] in
            await self?.scheduleObserverSync()
        }
    }

    private func healthAccessMessage(for requestStatus: HKAuthorizationRequestStatus) -> String {
        switch requestStatus {
        case .shouldRequest:
            return "Health access needs review. Tap Review Health Permissions to approve Apple Health categories."
        case .unnecessary:
            return "HealthKit says this app has already asked. iOS may not show the permission sheet again unless there are new categories to request."
        case .unknown:
            return "Health access status is unknown. Try Review Health Permissions, then run Check Health Access."
        @unknown default:
            return "Health access returned an unfamiliar status. Try Review Health Permissions, then run Check Health Access."
        }
    }

    private func healthCheckMessage(
        for snapshot: HealthSnapshot,
        readableDataTypes: [String]
    ) -> String {
        let checkedAt = snapshot.capturedAt.formatted(date: .omitted, time: .shortened)
        let hasReadableValues =
            snapshot.steps > 0
            || snapshot.moveKilocalories > 0
            || snapshot.exerciseMinutes > 0
            || snapshot.standHours > 0
            || snapshot.latestHeartRateBPM > 0
            || snapshot.sleepHours > 0
            || snapshot.latestWorkout != nil

        if hasReadableValues {
            return "HealthKit check worked at \(checkedAt). The app read today's Health snapshot without uploading it."
        }

        if !readableDataTypes.isEmpty {
            let readableList = readableDataTypes.joined(separator: ", ")
            return "HealthKit is reachable and recent \(readableList) data is readable, but today's dashboard values are empty."
        }

        return "HealthKit responded at \(checkedAt), but no readable samples were found in the last 30 days. If Health has data, open Health > Sharing > Apps > TRMNL Health Sync and turn on the read categories."
    }

    private func connectDirectTRMNL() throws {
        let webhookValue = trmnlWebhookURLInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            let webhookURL = webhookValue.normalizedURL,
            webhookURL.isTRMNLPrivatePluginWebhookURL
        else {
            throw AppModelError.invalidTRMNLWebhookURL
        }

        configuration.syncDestination = .directTRMNL
        configuration.deviceName = deviceNameInput
        try KeychainStore.save(webhookURL.absoluteString, for: .trmnlWebhookURL)
        try saveConfiguration()
        hasRegisteredSensors = false
    }

    private func connectHomeAssistant() async throws {
        guard let instanceURL = instanceURLInput.normalizedURL else {
            throw AppModelError.invalidInstanceURL
        }
        let accessToken = accessTokenInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !accessToken.isEmpty else {
            throw AppModelError.missingAccessToken
        }

        let registration = try await homeAssistantClient.register(
            instanceURL: instanceURL,
            accessToken: accessToken,
            deviceName: deviceNameInput
        )

        configuration.syncDestination = .homeAssistant
        configuration.instanceURLString = instanceURL.absoluteString
        configuration.deviceName = deviceNameInput
        configuration.registration = registration
        try KeychainStore.save(accessToken, for: .homeAssistantAccessToken)
        try saveConfiguration()
        hasRegisteredSensors = false
    }

    private func connectSelfHostedBridge() async throws {
        guard let bridgeURL = bridgeURLInput.normalizedURL else {
            throw AppModelError.invalidBridgeURL
        }
        let setupToken = bridgeSetupTokenInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !setupToken.isEmpty else {
            throw AppModelError.missingBridgeSetupToken
        }

        let webhookValue = trmnlWebhookURLInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedWebhook: String?
        if webhookValue.isEmpty {
            normalizedWebhook = nil
        } else if let webhookURL = webhookValue.normalizedURL,
                  webhookURL.isTRMNLPrivatePluginWebhookURL {
            normalizedWebhook = webhookURL.absoluteString
        } else {
            throw AppModelError.invalidTRMNLWebhookURL
        }

        let registration = try await selfHostedBridgeClient.register(
            serverURL: bridgeURL,
            setupToken: setupToken,
            deviceName: deviceNameInput,
            trmnlWebhookURL: normalizedWebhook
        )

        configuration.syncDestination = .selfHostedBridge
        configuration.bridgeURLString = bridgeURL.absoluteString
        configuration.bridgeRegistration = registration.persistedRegistration
        configuration.trmnlWebhookURLString = normalizedWebhook ?? ""
        configuration.deviceName = deviceNameInput
        try KeychainStore.save(setupToken, for: .selfHostedSetupToken)
        try KeychainStore.save(registration.deviceToken, for: .selfHostedDeviceToken)
        try saveConfiguration()
        hasRegisteredSensors = false
    }

    private func saveConfiguration() throws {
        try AppConfigurationStore.save(configuration)
    }

    private var hasSavedRegistration: Bool {
        switch configuration.syncDestination {
        case .directTRMNL:
            return KeychainStore.load(.trmnlWebhookURL) != nil
        case .homeAssistant:
            return configuration.registration != nil && configuration.instanceURL != nil
        case .selfHostedBridge:
            return configuration.bridgeRegistration != nil
                && configuration.bridgeURL != nil
                && KeychainStore.load(.selfHostedDeviceToken) != nil
        }
    }

    private var observerSyncDelaySeconds: Double {
        guard configuration.syncDestination == .directTRMNL else {
            return 15
        }
        guard let lastSuccessfulSync = configuration.lastSuccessfulSync else {
            return 15
        }
        return max(15, 300 - Date().timeIntervalSince(lastSuccessfulSync))
    }
}
