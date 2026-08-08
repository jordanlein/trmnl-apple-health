import AppIntents
import HealthKit
import Network

struct SyncHealthRingsToTRMNLIntent: AppIntent {
    static let title: LocalizedStringResource = "Sync Apple Health to TRMNL"
    static let description = IntentDescription(
        "Send today's Apple Health dashboard snapshot using your configured destination."
    )
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            let configuration = AppConfigurationStore.load()
            if let localURL = configuration.activeLocalNetworkURL,
               await ShortcutNetworkPreflight.shouldSkipLocalNetworkURL() {
                return .result(
                    dialog: "\(ShortcutSyncFailure.dialogForUnavailableLocalNetworkURL(localURL, configuration: configuration))"
                )
            }

            let result = try await withShortcutDeadline {
                try await DestinationSyncService().sync(
                    allowsCachedHealthSnapshot: true
                )
            }
            let snapshot = result.snapshot
            let cacheNote =
                result.snapshotSource == .cached
                ? " Used cached Health data from \(cachedSnapshotDateLabel(snapshot.capturedAt))."
                : ""

            return .result(
                dialog: "Synced Apple Health via \(result.outcome.dialogLabel): Move \(snapshot.movePercent)%, Exercise \(snapshot.exercisePercent)%, Stand \(snapshot.standPercent)%.\(cacheNote)"
            )
        } catch {
            let message = ShortcutSyncFailure.dialog(for: error)
            return .result(dialog: "\(message)")
        }
    }
}

private func cachedSnapshotDateLabel(_ date: Date) -> String {
    let dateStyle: Date.FormatStyle.DateStyle = Calendar.current.isDateInToday(date) ? .omitted : .abbreviated
    return date.formatted(date: dateStyle, time: .shortened)
}

private func withShortcutDeadline<T>(
    seconds: UInt64 = 22,
    operation: @Sendable @escaping () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        group.addTask {
            try await Task.sleep(nanoseconds: seconds * 1_000_000_000)
            throw ShortcutSyncTimeout()
        }

        defer { group.cancelAll() }
        guard let result = try await group.next() else {
            throw ShortcutSyncTimeout()
        }
        return result
    }
}

private struct ShortcutSyncTimeout: LocalizedError {
    var errorDescription: String? {
        "The sync took too long for this Shortcuts automation. Unlock the iPhone and run it again. If this keeps happening, confirm the destination is reachable from this iPhone."
    }
}

private enum ShortcutNetworkPreflight {
    static func shouldSkipLocalNetworkURL() async -> Bool {
        guard let path = await currentPath(), path.status == .satisfied else {
            return false
        }

        return path.usesInterfaceType(.cellular)
            && !path.usesInterfaceType(.wifi)
            && !path.usesInterfaceType(.other)
    }

    private static func currentPath() async -> NWPath? {
        let monitor = NWPathMonitor()
        let queue = DispatchQueue(label: "TRMNLHealthSync.ShortcutNetworkPreflight")
        monitor.start(queue: queue)
        try? await Task.sleep(nanoseconds: 250_000_000)
        let path = monitor.currentPath
        monitor.cancel()
        return path
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
    static func dialogForUnavailableLocalNetworkURL(
        _ localURL: URL,
        configuration: AppConfiguration
    ) -> String {
        let host = localURL.host ?? localURL.absoluteString
        return "Could not sync Apple Health via \(configuration.syncDestination.displayName). The configured address (\(host)) is a local network address, and this iPhone is currently using cellular data. Connect to home Wi-Fi, turn on your VPN, use a Home Assistant remote URL or Home Assistant Cloud, switch to TRMNL Direct, or use a reachable bridge URL."
    }

    static func dialog(for error: Error) -> String {
        let configuration = AppConfigurationStore.load()
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

        if let healthKitError = error as? HKError {
            switch healthKitError.code {
            case .errorDatabaseInaccessible:
                return "Health data is encrypted while the iPhone is locked, and there is no cached snapshot available yet. Unlock the phone and run the Shortcut once; later locked runs can publish that last known snapshot with its original date and time."
            case .errorAuthorizationNotDetermined:
                return "Health access has not been approved yet. Open the app and review Health permissions first."
            case .errorHealthDataRestricted:
                return "Health data is restricted on this iPhone."
            case .errorHealthDataUnavailable:
                return "Health data is not available on this device."
            default:
                return healthKitError.localizedDescription
            }
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
