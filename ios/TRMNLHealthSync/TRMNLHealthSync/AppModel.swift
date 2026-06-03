import Foundation
import Combine

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
            installObserversIfNeeded()
            try await syncNow(reason: "launch")
        } catch {
            statusMessage = error.localizedDescription
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

        let normalizedWebhook = trmnlWebhookURLInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let registration = try await selfHostedBridgeClient.register(
            serverURL: bridgeURL,
            setupToken: setupToken,
            deviceName: deviceNameInput,
            trmnlWebhookURL: normalizedWebhook.isEmpty ? nil : normalizedWebhook
        )

        configuration.syncDestination = .selfHostedBridge
        configuration.bridgeURLString = bridgeURL.absoluteString
        configuration.bridgeRegistration = registration.persistedRegistration
        configuration.trmnlWebhookURLString = normalizedWebhook
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
