import Foundation
import UIKit

enum SyncDestination: String, Codable, CaseIterable, Identifiable {
    case directTRMNL = "direct_trmnl"
    case homeAssistant = "home_assistant"
    case selfHostedBridge = "self_hosted_bridge"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .directTRMNL:
            return "TRMNL Direct"
        case .homeAssistant:
            return "Home Assistant"
        case .selfHostedBridge:
            return "Self-Hosted Bridge"
        }
    }

    var connectButtonLabel: String {
        switch self {
        case .directTRMNL:
            return "Connect TRMNL & Sync"
        case .homeAssistant:
            return "Connect Home Assistant & Sync"
        case .selfHostedBridge:
            return "Connect Bridge & Sync"
        }
    }
}

struct HomeAssistantRegistration: Codable, Equatable {
    let webhookID: String
    let cloudhookURL: URL?
    let remoteUIURL: URL?
    let secret: String?

    enum CodingKeys: String, CodingKey {
        case webhookID = "webhook_id"
        case cloudhookURL = "cloudhook_url"
        case remoteUIURL = "remote_ui_url"
        case secret
    }
}

struct SelfHostedBridgeRegistration: Codable, Equatable {
    let deviceID: String
    let deviceName: String
    let profileName: String
    let trmnlWebhookConfigured: Bool
    let registeredAt: Date

    enum CodingKeys: String, CodingKey {
        case deviceID = "device_id"
        case deviceName = "device_name"
        case profileName = "profile_name"
        case trmnlWebhookConfigured = "trmnl_webhook_configured"
        case registeredAt = "registered_at"
    }
}

struct SelfHostedBridgeRegistrationResponse: Codable, Equatable {
    let deviceID: String
    let deviceName: String
    let profileName: String
    let deviceToken: String
    let trmnlWebhookConfigured: Bool
    let defaultTRMNLWebhookConfigured: Bool
    let registeredAt: Date

    enum CodingKeys: String, CodingKey {
        case deviceID = "device_id"
        case deviceName = "device_name"
        case profileName = "profile_name"
        case deviceToken = "device_token"
        case trmnlWebhookConfigured = "trmnl_webhook_configured"
        case defaultTRMNLWebhookConfigured = "default_trmnl_webhook_configured"
        case registeredAt = "registered_at"
    }

    var persistedRegistration: SelfHostedBridgeRegistration {
        SelfHostedBridgeRegistration(
            deviceID: deviceID,
            deviceName: deviceName,
            profileName: profileName,
            trmnlWebhookConfigured: trmnlWebhookConfigured || defaultTRMNLWebhookConfigured,
            registeredAt: registeredAt
        )
    }
}

struct SelfHostedBridgeSyncResponse: Codable, Equatable {
    let deviceID: String
    let storedAt: Date
    let pushedToTRMNL: Bool
    let trmnlWebhookConfigured: Bool
    let trmnlPushError: String?

    enum CodingKeys: String, CodingKey {
        case deviceID = "device_id"
        case storedAt = "stored_at"
        case pushedToTRMNL = "pushed_to_trmnl"
        case trmnlWebhookConfigured = "trmnl_webhook_configured"
        case trmnlPushError = "trmnl_push_error"
    }
}

struct AppConfiguration: Codable {
    var syncDestination: SyncDestination = .directTRMNL
    var instanceURLString: String = ""
    var deviceName: String = DeviceIdentity.defaultDeviceName
    var registration: HomeAssistantRegistration?
    var bridgeURLString: String = ""
    var bridgeRegistration: SelfHostedBridgeRegistration?
    var trmnlWebhookURLString: String = ""
    var lastSuccessfulSync: Date?
    var lastSnapshot: HealthSnapshot?

    var instanceURL: URL? {
        instanceURLString.normalizedURL
    }

    var bridgeURL: URL? {
        bridgeURLString.normalizedURL
    }

    var trmnlWebhookURL: URL? {
        trmnlWebhookURLString.normalizedURL
    }

    init() {}

    enum CodingKeys: String, CodingKey {
        case syncDestination
        case instanceURLString
        case deviceName
        case registration
        case bridgeURLString
        case bridgeRegistration
        case trmnlWebhookURLString
        case lastSuccessfulSync
        case lastSnapshot
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        syncDestination =
            try container.decodeIfPresent(SyncDestination.self, forKey: .syncDestination)
            ?? .directTRMNL
        instanceURLString =
            try container.decodeIfPresent(String.self, forKey: .instanceURLString) ?? ""
        deviceName =
            try container.decodeIfPresent(String.self, forKey: .deviceName)
            ?? DeviceIdentity.defaultDeviceName
        registration =
            try container.decodeIfPresent(HomeAssistantRegistration.self, forKey: .registration)
        bridgeURLString =
            try container.decodeIfPresent(String.self, forKey: .bridgeURLString) ?? ""
        bridgeRegistration =
            try container.decodeIfPresent(SelfHostedBridgeRegistration.self, forKey: .bridgeRegistration)
        trmnlWebhookURLString =
            try container.decodeIfPresent(String.self, forKey: .trmnlWebhookURLString) ?? ""
        lastSuccessfulSync =
            try container.decodeIfPresent(Date.self, forKey: .lastSuccessfulSync)
        lastSnapshot =
            try container.decodeIfPresent(HealthSnapshot.self, forKey: .lastSnapshot)
    }
}

struct HealthSnapshot: Codable, Equatable {
    let capturedAt: Date
    let deviceName: String
    let profileName: String
    let steps: Int
    let distanceKilometers: Double
    let distanceMiles: Double
    let flightsClimbed: Int
    let moveKilocalories: Int
    let moveGoalKilocalories: Int
    let movePercent: Int
    let exerciseMinutes: Int
    let exerciseGoalMinutes: Int
    let exercisePercent: Int
    let standHours: Int
    let standGoalHours: Int
    let standPercent: Int
    let latestHeartRateBPM: Int
    let sleepHours: Double
    let latestWorkout: LatestWorkout?

    var capturedAtISO8601: String {
        ISO8601DateFormatter().string(from: capturedAt)
    }

    var dateLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: capturedAt)
    }

    var snapshotAttributes: [String: Any] {
        var attributes: [String: Any] = [
            "captured_at": capturedAtISO8601,
            "date_label": dateLabel,
            "device_name": deviceName,
            "profile_name": profileName,
            "steps": steps,
            "distance_km": rounded(distanceKilometers, digits: 2),
            "distance_mi": rounded(distanceMiles, digits: 2),
            "flights_climbed": flightsClimbed,
            "move_kcal": moveKilocalories,
            "move_goal_kcal": moveGoalKilocalories,
            "move_percent": movePercent,
            "exercise_minutes": exerciseMinutes,
            "exercise_goal_minutes": exerciseGoalMinutes,
            "exercise_percent": exercisePercent,
            "stand_hours": standHours,
            "stand_goal_hours": standGoalHours,
            "stand_percent": standPercent,
            "latest_heart_rate_bpm": latestHeartRateBPM,
            "sleep_hours": rounded(sleepHours, digits: 1),
        ]
        if let latestWorkout {
            attributes["latest_workout"] = latestWorkout.snapshotAttributes
        }
        return attributes
    }

    var registrationPayloads: [[String: Any]] {
        [
            [
                "type": "sensor",
                "unique_id": "trmnl_health_sync_snapshot",
                "name": "Health Snapshot",
                "state": capturedAtISO8601,
                "icon": "mdi:heart-pulse",
                "attributes": snapshotAttributes,
            ],
            [
                "type": "sensor",
                "unique_id": "trmnl_health_sync_steps",
                "name": "Steps Today",
                "state": steps,
                "icon": "mdi:shoe-print",
                "unit_of_measurement": "steps",
                "state_class": "measurement",
                "attributes": ["captured_at": capturedAtISO8601],
            ],
            [
                "type": "sensor",
                "unique_id": "trmnl_health_sync_distance",
                "name": "Distance Today",
                "state": rounded(distanceMiles, digits: 2),
                "icon": "mdi:map-marker-distance",
                "unit_of_measurement": "mi",
                "state_class": "measurement",
                "attributes": ["captured_at": capturedAtISO8601],
            ],
            [
                "type": "sensor",
                "unique_id": "trmnl_health_sync_move",
                "name": "Move Ring",
                "state": moveKilocalories,
                "icon": "mdi:fire-circle",
                "unit_of_measurement": "kcal",
                "state_class": "measurement",
                "attributes": [
                    "goal": moveGoalKilocalories,
                    "percent": movePercent,
                    "captured_at": capturedAtISO8601,
                ],
            ],
            [
                "type": "sensor",
                "unique_id": "trmnl_health_sync_exercise",
                "name": "Exercise Ring",
                "state": exerciseMinutes,
                "icon": "mdi:run-fast",
                "unit_of_measurement": "min",
                "state_class": "measurement",
                "attributes": [
                    "goal": exerciseGoalMinutes,
                    "percent": exercisePercent,
                    "captured_at": capturedAtISO8601,
                ],
            ],
            [
                "type": "sensor",
                "unique_id": "trmnl_health_sync_stand",
                "name": "Stand Ring",
                "state": standHours,
                "icon": "mdi:human-handsup",
                "unit_of_measurement": "h",
                "state_class": "measurement",
                "attributes": [
                    "goal": standGoalHours,
                    "percent": standPercent,
                    "captured_at": capturedAtISO8601,
                ],
            ],
        ]
    }

    var updatePayloads: [[String: Any]] {
        registrationPayloads.map { payload in
            [
                "type": payload["type"] as Any,
                "unique_id": payload["unique_id"] as Any,
                "state": payload["state"] as Any,
                "icon": payload["icon"] as Any,
                "attributes": payload["attributes"] as Any,
            ]
        }
    }

    var trmnlMergeVariables: TRMNLMergeVariables {
        TRMNLMergeVariables(
            profileName: profileName,
            deviceName: deviceName,
            capturedAt: capturedAtISO8601,
            syncTimeLabel: capturedAt.formatted(date: .omitted, time: .shortened),
            dateLabel: dateLabel,
            rings: TRMNLRings(
                move: moveKilocalories,
                moveGoal: moveGoalKilocalories,
                movePercent: movePercent,
                exercise: exerciseMinutes,
                exerciseGoal: exerciseGoalMinutes,
                exercisePercent: exercisePercent,
                stand: standHours,
                standGoal: standGoalHours,
                standPercent: standPercent
            ),
            activity: TRMNLActivity(
                steps: steps,
                distanceKilometers: rounded(distanceKilometers, digits: 2),
                distanceMiles: rounded(distanceMiles, digits: 2),
                flightsClimbed: flightsClimbed
            ),
            health: TRMNLHealth(
                latestHeartRateBPM: latestHeartRateBPM,
                sleepHours: rounded(sleepHours, digits: 1),
                latestWorkout: latestWorkout.map {
                    TRMNLWorkout(
                        activityType: $0.activityType,
                        startDate: ISO8601DateFormatter().string(from: $0.startDate),
                        durationSeconds: Int($0.durationSeconds.rounded()),
                        totalEnergyBurnedKilocalories: Int($0.totalEnergyBurnedKilocalories.rounded())
                    )
                }
            )
        )
    }

    private func rounded(_ value: Double, digits: Int) -> Double {
        let multiplier = pow(10.0, Double(digits))
        return (value * multiplier).rounded() / multiplier
    }
}

struct LatestWorkout: Codable, Equatable {
    let activityType: String
    let startDate: Date
    let durationSeconds: Double
    let totalEnergyBurnedKilocalories: Double

    var snapshotAttributes: [String: Any] {
        [
            "activity_type": activityType,
            "start_date": ISO8601DateFormatter().string(from: startDate),
            "duration_seconds": Int(durationSeconds.rounded()),
            "total_energy_burned_kcal": Int(totalEnergyBurnedKilocalories.rounded()),
        ]
    }
}

struct TRMNLMergeVariables: Encodable {
    let profileName: String
    let deviceName: String
    let capturedAt: String
    let syncTimeLabel: String
    let dateLabel: String
    let rings: TRMNLRings
    let activity: TRMNLActivity
    let health: TRMNLHealth
}

struct TRMNLHealth: Encodable {
    let latestHeartRateBPM: Int
    let sleepHours: Double
    let latestWorkout: TRMNLWorkout?
}

struct TRMNLWorkout: Encodable {
    let activityType: String
    let startDate: String
    let durationSeconds: Int
    let totalEnergyBurnedKilocalories: Int
}

struct TRMNLRings: Encodable {
    let move: Int
    let moveGoal: Int
    let movePercent: Int
    let exercise: Int
    let exerciseGoal: Int
    let exercisePercent: Int
    let stand: Int
    let standGoal: Int
    let standPercent: Int
}

struct TRMNLActivity: Encodable {
    let steps: Int
    let distanceKilometers: Double
    let distanceMiles: Double
    let flightsClimbed: Int

    enum CodingKeys: String, CodingKey {
        case steps
        case distanceKilometers = "distance_km"
        case distanceMiles = "distance_mi"
        case flightsClimbed = "flights_climbed"
    }
}

struct SelfHostedBridgeSnapshotRequest: Encodable {
    let snapshot: HealthSnapshot
    let trmnlWebhookURL: String?

    enum CodingKeys: String, CodingKey {
        case snapshot
        case trmnlWebhookURL = "trmnl_webhook_url"
    }
}

enum DeviceIdentity {
    private static let defaultsKey = "DeviceIdentity.identifier"

    static var currentID: String {
        let defaults = UserDefaults.standard
        if let existing = defaults.string(forKey: defaultsKey) {
            return existing
        }
        let created = UUID().uuidString.lowercased()
        defaults.set(created, forKey: defaultsKey)
        return created
    }

    static var defaultDeviceName: String {
        UIDevice.current.name
    }
}

enum AppModelError: LocalizedError {
    case invalidTRMNLWebhookURL
    case missingTRMNLWebhookURL
    case invalidInstanceURL
    case missingAccessToken
    case missingRegistration
    case invalidBridgeURL
    case missingBridgeSetupToken
    case missingBridgeRegistration
    case healthDataUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidTRMNLWebhookURL:
            return "Enter a valid TRMNL Private Plugin webhook URL."
        case .missingTRMNLWebhookURL:
            return "Connect a TRMNL Private Plugin webhook before running this sync."
        case .invalidInstanceURL:
            return "Enter a valid Home Assistant URL."
        case .missingAccessToken:
            return "Enter a Home Assistant long-lived access token."
        case .missingRegistration:
            return "The app is not registered with Home Assistant yet."
        case .invalidBridgeURL:
            return "Enter a valid self-hosted bridge URL."
        case .missingBridgeSetupToken:
            return "Enter the self-hosted bridge setup token."
        case .missingBridgeRegistration:
            return "The app is not paired with the self-hosted bridge yet."
        case .healthDataUnavailable:
            return "Health data is not available on this device."
        }
    }
}

extension String {
    var normalizedURL: URL? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let url = URL(string: trimmed), url.scheme != nil {
            return url
        }

        return URL(string: "http://\(trimmed)")
    }
}

extension URL {
    var isTRMNLPrivatePluginWebhookURL: Bool {
        scheme == "https"
            && host == "trmnl.com"
            && pathComponents.count == 4
            && pathComponents[1] == "api"
            && pathComponents[2] == "custom_plugins"
            && !pathComponents[3].isEmpty
    }
}

extension JSONEncoder {
    static var trmnlHealthAPI: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

extension JSONDecoder {
    static var trmnlHealthAPI: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
