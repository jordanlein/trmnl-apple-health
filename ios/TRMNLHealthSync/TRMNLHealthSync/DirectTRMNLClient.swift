import Foundation

extension URLSession {
    static let trmnlSync: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 25
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration)
    }()

    func trmnlData(for request: URLRequest, attempts: Int = 2) async throws -> (Data, URLResponse) {
        var lastError: Error?

        for attempt in 1...max(1, attempts) {
            do {
                return try await data(for: request)
            } catch {
                lastError = error
                guard attempt < attempts, error.isTransientNetworkFailure else {
                    throw error
                }

                try await Task.sleep(nanoseconds: UInt64(attempt) * 750_000_000)
            }
        }

        throw lastError ?? URLError(.unknown)
    }
}

extension Error {
    var isTransientNetworkFailure: Bool {
        guard let urlError = self as? URLError else { return false }
        switch urlError.code {
        case .timedOut,
            .networkConnectionLost,
            .notConnectedToInternet,
            .cannotFindHost,
            .cannotConnectToHost,
            .dnsLookupFailed,
            .internationalRoamingOff,
            .dataNotAllowed:
            return true
        default:
            return false
        }
    }
}

struct DirectTRMNLClient {
    private let session = URLSession.trmnlSync

    func updateSnapshot(
        webhookURL: URL,
        snapshot: HealthSnapshot,
        snapshotSource: HealthSnapshotSource
    ) async throws {
        let payload = TRMNLWebhookRequest(
            mergeVariables: snapshot.trmnlMergeVariables(snapshotSource: snapshotSource)
        )
        let body = try JSONEncoder.trmnlHealthAPI.encode(payload)
        guard body.count < 2_048 else {
            throw AppModelError.trmnlPayloadTooLarge(body.count)
        }

        var request = URLRequest(url: webhookURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("trmnl-health-sync-ios/0.3.0", forHTTPHeaderField: "User-Agent")
        request.httpBody = body

        let (data, response) = try await session.trmnlData(for: request)
        try validate(response: response, data: data)
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown response body"
            throw NSError(
                domain: "DirectTRMNLClient",
                code: http.statusCode,
                userInfo: [NSLocalizedDescriptionKey: body]
            )
        }
    }
}

private struct TRMNLWebhookRequest: Encodable {
    let mergeVariables: TRMNLMergeVariables
}
