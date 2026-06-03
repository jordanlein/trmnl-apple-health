import Foundation

struct SelfHostedBridgeClient {
    private let session = URLSession.trmnlSync

    func register(
        serverURL: URL,
        setupToken: String,
        deviceName: String,
        trmnlWebhookURL: String?
    ) async throws -> SelfHostedBridgeRegistrationResponse {
        let payload = DeviceRegistrationRequest(
            setupToken: setupToken,
            deviceID: DeviceIdentity.currentID,
            deviceName: deviceName,
            appID: Bundle.main.bundleIdentifier ?? "TRMNLHealthSync",
            appName: "TRMNL Health Sync",
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.2.0",
            platform: "ios",
            profileName: "Apple Health",
            trmnlWebhookURL: normalizedWebhook(trmnlWebhookURL)
        )

        var request = URLRequest(url: serverURL.appendingPathComponent("api/v1/devices/register"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder.trmnlHealthAPI.encode(payload)

        let (data, response) = try await session.trmnlData(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder.trmnlHealthAPI.decode(SelfHostedBridgeRegistrationResponse.self, from: data)
    }

    func updateSnapshot(
        serverURL: URL,
        deviceToken: String,
        snapshot: HealthSnapshot,
        trmnlWebhookURL: String?
    ) async throws -> SelfHostedBridgeSyncResponse {
        let payload = SelfHostedBridgeSnapshotRequest(
            snapshot: snapshot,
            trmnlWebhookURL: normalizedWebhook(trmnlWebhookURL)
        )

        var request = URLRequest(url: serverURL.appendingPathComponent("api/v1/snapshots"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(deviceToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder.trmnlHealthAPI.encode(payload)

        let (data, response) = try await session.trmnlData(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder.trmnlHealthAPI.decode(SelfHostedBridgeSyncResponse.self, from: data)
    }

    private func normalizedWebhook(_ rawValue: String?) -> String? {
        guard let rawValue else { return nil }
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown response body"
            throw NSError(
                domain: "SelfHostedBridgeClient",
                code: http.statusCode,
                userInfo: [NSLocalizedDescriptionKey: body]
            )
        }
    }
}

private struct DeviceRegistrationRequest: Encodable {
    let setupToken: String
    let deviceID: String
    let deviceName: String
    let appID: String
    let appName: String
    let appVersion: String
    let platform: String
    let profileName: String
    let trmnlWebhookURL: String?

    enum CodingKeys: String, CodingKey {
        case setupToken = "setup_token"
        case deviceID = "device_id"
        case deviceName = "device_name"
        case appID = "app_id"
        case appName = "app_name"
        case appVersion = "app_version"
        case platform
        case profileName = "profile_name"
        case trmnlWebhookURL = "trmnl_webhook_url"
    }
}
