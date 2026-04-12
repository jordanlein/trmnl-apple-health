import Foundation
import Combine

@MainActor
final class AppModel: ObservableObject {
    @Published var instanceURLInput: String
    @Published var accessTokenInput: String
    @Published var deviceNameInput: String
    @Published var lastSnapshot: HealthSnapshot?
    @Published var statusMessage = "Ready"
    @Published var isBusy = false
    @Published var didFinishInitialLoad = false

    private var configuration: AppConfiguration
    private let healthKitStore = HealthKitStore()
    private let homeAssistantClient = HomeAssistantClient()
    private var observersInstalled = false
    private let defaultsKey = "TRMNLHealthSync.configuration"
    private var hasRegisteredSensors = false

    init() {
        let loaded = Self.loadConfiguration(defaultsKey: defaultsKey)
        configuration = loaded
        instanceURLInput = loaded.instanceURLString
        accessTokenInput = KeychainStore.loadAccessToken() ?? ""
        deviceNameInput = loaded.deviceName
    }

    func bootstrap() async {
        guard !didFinishInitialLoad else { return }
        didFinishInitialLoad = true

        guard configuration.registration != nil || !instanceURLInput.isEmpty else {
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
        guard configuration.registration != nil else { return }
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
            guard let instanceURL = instanceURLInput.normalizedURL else {
                throw AppModelError.invalidInstanceURL
            }
            let accessToken = accessTokenInput.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !accessToken.isEmpty else {
                throw AppModelError.missingAccessToken
            }

            try await healthKitStore.requestAuthorization()

            let registration = try await homeAssistantClient.register(
                instanceURL: instanceURL,
                accessToken: accessToken,
                deviceName: deviceNameInput
            )

            configuration.instanceURLString = instanceURL.absoluteString
            configuration.deviceName = deviceNameInput
            configuration.registration = registration
            try save(accessToken: accessToken)

            installObserversIfNeeded()
            hasRegisteredSensors = false
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
            statusMessage = "Synced successfully."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func resetConfiguration() {
        configuration = AppConfiguration()
        instanceURLInput = ""
        accessTokenInput = ""
        deviceNameInput = DeviceIdentity.defaultDeviceName
        lastSnapshot = nil
        hasRegisteredSensors = false
        observersInstalled = false
        KeychainStore.clearAccessToken()
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
        guard configuration.registration != nil else {
            throw AppModelError.missingRegistration
        }

        let snapshot = try await healthKitStore.fetchDailySnapshot(deviceName: deviceNameInput)
        lastSnapshot = snapshot

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

        configuration.lastSuccessfulSync = .now
        try save(accessToken: accessTokenInput)
        statusMessage = "Last sync: \(snapshot.capturedAt.formatted(date: .omitted, time: .shortened)) (\(reason))"
    }

    private func installObserversIfNeeded() {
        guard !observersInstalled else { return }
        observersInstalled = true
        healthKitStore.installObservers { [weak self] in
            await self?.handleObserverUpdate()
        }
    }

    private func save(accessToken: String) throws {
        try KeychainStore.saveAccessToken(accessToken)
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
}
