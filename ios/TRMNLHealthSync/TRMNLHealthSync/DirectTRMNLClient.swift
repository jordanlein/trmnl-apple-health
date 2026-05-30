import Foundation

struct DirectTRMNLClient {
    private let session = URLSession.shared

    func updateSnapshot(webhookURL: URL, snapshot: HealthSnapshot) async throws {
        let payload = TRMNLWebhookRequest(mergeVariables: snapshot.trmnlMergeVariables)
        var request = URLRequest(url: webhookURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("trmnl-health-sync-ios/0.3.0", forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONEncoder.trmnlHealthAPI.encode(payload)

        let (data, response) = try await session.data(for: request)
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
    let mergeStrategy = "deep_merge"
}
