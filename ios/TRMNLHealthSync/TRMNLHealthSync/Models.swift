import Foundation
import UIKit

enum SyncDestination: String, Codable, CaseIterable, Identifiable {
    case homeAssistant = "home_assistant"
    case selfHostedBridge = "self_hosted_bridge"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .homeAssistant:
            return "Home Assistant"
        case .selfHostedBridge:
            return "Self-Hosted Bridge"
        }
    }

    var connectButtonLabel: String {
        switch self {
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
    var syncDestination: SyncDestination = .homeAssistant
    var instanceURLString: String = ""
    var deviceName: String = DeviceIdentity.defaultDeviceName
    var registration: HomeAssistantRegistration?
    var bridgeURLString: String = ""
    var bridgeRegistration: SelfHostedBridgeRegistration?
    var trmnlWebhookURLString: String = ""
    var lastSuccessfulSync: Date?

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
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        syncDestination =
            try container.decodeIfPresent(SyncDestination.self, forKey: .syncDestination)
            ?? .homeAssistant
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

    var capturedAtISO8601: String {
        ISO8601DateFormatter().string(from: capturedAt)
    }

    var dateLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: capturedAt)
    }

    var snapshotAttributes: [String: Any] {
        [
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
        ]
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

    private func rounded(_ value: Double, digits: Int) -> Double {
        let multiplier = pow(10.0, Double(digits))
        return (value * multiplier).rounded() / multiplier
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
    case invalidInstanceURL
    case missingAccessToken
    case missingRegistration
    case invalidBridgeURL
    case missingBridgeSetupToken
    case missingBridgeRegistration
    case healthDataUnavailable

    var errorDescription: String? {
        switch self {
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
