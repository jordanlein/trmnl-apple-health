import Foundation
import UIKit

struct HomeAssistantClient {
    private let session = URLSession.trmnlSync

    @MainActor
    func register(
        instanceURL: URL,
        accessToken: String,
        deviceName: String
    ) async throws -> HomeAssistantRegistration {
        let payload: [String: Any] = [
            "device_id": DeviceIdentity.currentID,
            "app_id": Bundle.main.bundleIdentifier ?? "TRMNLHealthSync",
            "app_name": "TRMNL Health Sync",
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0",
            "device_name": deviceName,
            "manufacturer": "Apple",
            "model": UIDevice.current.model,
            "os_name": UIDevice.current.systemName,
            "os_version": UIDevice.current.systemVersion,
            "supports_encryption": false,
        ]

        let url = instanceURL.appendingPathComponent("api/mobile_app/registrations")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await session.trmnlData(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(HomeAssistantRegistration.self, from: data)
    }

    func registerSensors(
        configuration: AppConfiguration,
        snapshot: HealthSnapshot,
        snapshotSource: HealthSnapshotSource
    ) async throws {
        for payload in snapshot.registrationPayloads(snapshotSource: snapshotSource) {
            let envelope: [String: Any] = [
                "type": "register_sensor",
                "data": payload,
            ]
            _ = try await sendWebhook(
                configuration: configuration,
                jsonObject: envelope
            )
        }
    }

    func updateSensors(
        configuration: AppConfiguration,
        snapshot: HealthSnapshot,
        snapshotSource: HealthSnapshotSource
    ) async throws {
        let envelope: [String: Any] = [
            "type": "update_sensor_states",
            "data": snapshot.updatePayloads(snapshotSource: snapshotSource),
        ]
        _ = try await sendWebhook(configuration: configuration, jsonObject: envelope)
    }

    private func sendWebhook(
        configuration: AppConfiguration,
        jsonObject: [String: Any]
    ) async throws -> Data {
        guard let registration = configuration.registration else {
            throw AppModelError.missingRegistration
        }

        let candidateURLs = webhookCandidates(
            registration: registration,
            instanceURL: configuration.instanceURL
        )

        var lastError: Error?
        for url in candidateURLs {
            do {
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try JSONSerialization.data(withJSONObject: jsonObject)
                let (data, response) = try await session.trmnlData(for: request)
                try validate(response: response, data: data)
                return data
            } catch {
                lastError = error
            }
        }

        throw lastError ?? AppModelError.missingRegistration
    }

    private func webhookCandidates(
        registration: HomeAssistantRegistration,
        instanceURL: URL?
    ) -> [URL] {
        var candidates: [URL] = []

        if let cloudhookURL = registration.cloudhookURL {
            candidates.append(cloudhookURL)
        }

        if let remoteUIURL = registration.remoteUIURL {
            candidates.append(
                remoteUIURL
                    .appendingPathComponent("api")
                    .appendingPathComponent("webhook")
                    .appendingPathComponent(registration.webhookID)
            )
        }

        if let instanceURL {
            candidates.append(
                instanceURL
                    .appendingPathComponent("api")
                    .appendingPathComponent("webhook")
                    .appendingPathComponent(registration.webhookID)
            )
        }

        return candidates
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown response body"
            throw NSError(
                domain: "HomeAssistantClient",
                code: http.statusCode,
                userInfo: [NSLocalizedDescriptionKey: body]
            )
        }
    }
}
