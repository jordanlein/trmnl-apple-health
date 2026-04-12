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

    private var configuration: AppConfiguration
    private let healthKitStore = HealthKitStore()
    private let homeAssistantClient = HomeAssistantClient()
    private let selfHostedBridgeClient = SelfHostedBridgeClient()
    private var observersInstalled = false
    private let defaultsKey = "TRMNLHealthSync.configuration"
    private var hasRegisteredSensors = false

    init() {
        let loaded = Self.loadConfiguration(defaultsKey: defaultsKey)
        configuration = loaded
        syncDestinationInput = loaded.syncDestination
        instanceURLInput = loaded.instanceURLString
        accessTokenInput = KeychainStore.load(.homeAssistantAccessToken) ?? ""
        bridgeURLInput = loaded.bridgeURLString
        bridgeSetupTokenInput = KeychainStore.load(.selfHostedSetupToken) ?? ""
        trmnlWebhookURLInput = loaded.trmnlWebhookURLString
        deviceNameInput = loaded.deviceName
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
        syncDestinationInput = .homeAssistant
        instanceURLInput = ""
        accessTokenInput = ""
        bridgeURLInput = ""
        bridgeSetupTokenInput = ""
        trmnlWebhookURLInput = ""
        deviceNameInput = DeviceIdentity.defaultDeviceName
        lastSnapshot = nil
        hasRegisteredSensors = false
        observersInstalled = false
        KeychainStore.clearAll()
        UserDefaults.standard.removeObject(forKey: defaultsKey)
        statusMessage = "Cleared local configuration."
    }

    func handleObserverUpdate() async {
        do {
            try await syncNow(reason: "healthkit")
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func syncNow(reason: String) async throws {
        let snapshot = try await healthKitStore.fetchDailySnapshot(deviceName: deviceNameInput)
        lastSnapshot = snapshot

        switch configuration.syncDestination {
        case .homeAssistant:
            guard configuration.registration != nil else {
                throw AppModelError.missingRegistration
            }

            if !hasRegisteredSensors {
                try await homeAssistantClient.registerSensors(
                    configuration: configuration,
                    snapshot: snapshot
                )
                hasRegisteredSensors = true
            }

            try await homeAssistantClient.updateSensors(
                configuration: configuration,
                snapshot: snapshot
            )

        case .selfHostedBridge:
            guard
                configuration.bridgeRegistration != nil,
                let bridgeURL = configuration.bridgeURL
            else {
                throw AppModelError.missingBridgeRegistration
            }
            guard
                let deviceToken = KeychainStore.load(.selfHostedDeviceToken),
                !deviceToken.isEmpty
            else {
                throw AppModelError.missingBridgeRegistration
            }

            let result = try await selfHostedBridgeClient.updateSnapshot(
                serverURL: bridgeURL,
                deviceToken: deviceToken,
                snapshot: snapshot,
                trmnlWebhookURL: configuration.trmnlWebhookURLString
            )

            if result.trmnlWebhookConfigured {
                statusMessage = result.pushedToTRMNL
                    ? "Last sync: \(snapshot.capturedAt.formatted(date: .omitted, time: .shortened)) (\(reason), pushed)"
                    : "Last sync: \(snapshot.capturedAt.formatted(date: .omitted, time: .shortened)) (\(reason), stored)"
            } else {
                statusMessage = "Last sync: \(snapshot.capturedAt.formatted(date: .omitted, time: .shortened)) (\(reason), webhook not configured)"
            }
        }

        configuration.lastSuccessfulSync = .now
        try saveConfiguration()
        if configuration.syncDestination == .homeAssistant {
            statusMessage = "Last sync: \(snapshot.capturedAt.formatted(date: .omitted, time: .shortened)) (\(reason))"
        }
    }

    private func installObserversIfNeeded() {
        guard !observersInstalled else { return }
        observersInstalled = true
        healthKitStore.installObservers { [weak self] in
            await self?.handleObserverUpdate()
        }
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
        let data = try JSONEncoder().encode(configuration)
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    private static func loadConfiguration(defaultsKey: String) -> AppConfiguration {
        guard
            let data = UserDefaults.standard.data(forKey: defaultsKey),
            let decoded = try? JSONDecoder().decode(AppConfiguration.self, from: data)
        else {
            return AppConfiguration()
        }
        return decoded
    }

    private var hasSavedRegistration: Bool {
        switch configuration.syncDestination {
        case .homeAssistant:
            return configuration.registration != nil && configuration.instanceURL != nil
        case .selfHostedBridge:
            return configuration.bridgeRegistration != nil
                && configuration.bridgeURL != nil
                && KeychainStore.load(.selfHostedDeviceToken) != nil
        }
    }
}
