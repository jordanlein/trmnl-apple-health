import Foundation
import UIKit

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

struct AppConfiguration: Codable {
    var instanceURLString: String = ""
    var deviceName: String = DeviceIdentity.defaultDeviceName
    var registration: HomeAssistantRegistration?
    var lastSuccessfulSync: Date?

    var instanceURL: URL? {
        URL(string: instanceURLString.trimmingCharacters(in: .whitespacesAndNewlines))
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
    case healthDataUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidInstanceURL:
            return "Enter a valid Home Assistant URL."
        case .missingAccessToken:
            return "Enter a Home Assistant long-lived access token."
        case .missingRegistration:
            return "The app is not registered with Home Assistant yet."
        case .healthDataUnavailable:
            return "Health data is not available on this device."
        }
    }
}
