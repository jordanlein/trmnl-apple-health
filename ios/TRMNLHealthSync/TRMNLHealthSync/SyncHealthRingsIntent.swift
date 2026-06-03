import AppIntents

struct SyncHealthRingsToTRMNLIntent: AppIntent {
    static let title: LocalizedStringResource = "Sync Apple Health to TRMNL"
    static let description = IntentDescription(
        "Send today's Apple Health dashboard snapshot using your configured destination."
    )
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            let result = try await DestinationSyncService().sync(
                allowsCachedHealthSnapshot: true
            )
            let snapshot = result.snapshot
            let cacheNote =
                result.snapshotSource == .cached
                ? " Used cached Health data from \(snapshot.capturedAt.formatted(date: .omitted, time: .shortened))."
                : ""

            return .result(
                dialog: "Synced Apple Health via \(result.outcome.dialogLabel): Move \(snapshot.movePercent)%, Exercise \(snapshot.exercisePercent)%, Stand \(snapshot.standPercent)%.\(cacheNote)"
            )
        } catch {
            let configuration = AppConfigurationStore.load()
            let message = ShortcutSyncFailure.dialog(
                for: error,
                configuration: configuration
            )
            return .result(dialog: "\(message)")
        }
    }
}

struct TRMNLHealthShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SyncHealthRingsToTRMNLIntent(),
            phrases: [
                "Sync Apple Health with \(.applicationName)",
                "Refresh my TRMNL health dashboard with \(.applicationName)",
            ],
            shortTitle: "Sync Apple Health",
            systemImageName: "heart.circle"
        )
    }
}

private enum ShortcutSyncFailure {
    static func dialog(for error: Error, configuration: AppConfiguration) -> String {
        var message = "Could not sync Apple Health via \(configuration.syncDestination.displayName). "
        message += explanation(for: error)

        if let localURL = configuration.activeLocalNetworkURL {
            let host = localURL.host ?? localURL.absoluteString
            message += " The configured address (\(host)) looks like a local network address, so this Shortcut can only reach it while your iPhone is on that network or VPN. Use a Home Assistant remote URL, Home Assistant Cloud, TRMNL Direct, or a reachable bridge URL if you want automations to run away from home."
        }

        return message
    }

    private static func explanation(for error: Error) -> String {
        if let appError = error as? AppModelError,
           let description = appError.errorDescription {
            return description
        }

        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet:
                return "The phone was not connected to the internet."
            case .timedOut:
                return "The destination did not respond before the Shortcut timeout."
            case .cannotFindHost, .dnsLookupFailed:
                return "The destination hostname could not be found."
            case .cannotConnectToHost:
                return "The destination host could not be reached."
            case .networkConnectionLost:
                return "The network connection dropped during the sync."
            case .dataNotAllowed:
                return "iOS did not allow data access for this background run."
            default:
                return urlError.localizedDescription
            }
        }

        let description = error.localizedDescription
        guard !description.isEmpty else {
            return "iOS reported an unknown error."
        }
        return description.count > 220
            ? String(description.prefix(220)) + "..."
            : description
    }
}

private extension AppConfiguration {
    var activeLocalNetworkURL: URL? {
        switch syncDestination {
        case .directTRMNL:
            return nil
        case .homeAssistant:
            return instanceURL?.isLikelyLocalNetworkURL == true ? instanceURL : nil
        case .selfHostedBridge:
            return bridgeURL?.isLikelyLocalNetworkURL == true ? bridgeURL : nil
        }
    }
}

private extension URL {
    var isLikelyLocalNetworkURL: Bool {
        guard let host = host?.lowercased() else { return false }

        if host == "localhost" || host.hasSuffix(".local") {
            return true
        }

        if host.hasPrefix("10.") || host.hasPrefix("192.168.") {
            return true
        }

        let private172Prefixes = (16...31).map { "172.\($0)." }
        return private172Prefixes.contains { host.hasPrefix($0) }
    }
}
