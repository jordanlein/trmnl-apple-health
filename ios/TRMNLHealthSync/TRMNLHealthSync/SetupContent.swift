import SwiftUI

struct SetupStep: Identifiable {
    let systemImage: String
    let title: String
    let detail: String

    var id: String { title }
}

extension SyncDestination {
    var systemImage: String {
        switch self {
        case .directTRMNL:
            return "rectangle.connected.to.line.below"
        case .homeAssistant:
            return "house.fill"
        case .selfHostedBridge:
            return "server.rack"
        }
    }

    var tint: Color {
        switch self {
        case .directTRMNL:
            return .blue
        case .homeAssistant:
            return .orange
        case .selfHostedBridge:
            return .purple
        }
    }

    var shortSummary: String {
        switch self {
        case .directTRMNL:
            return "Send your complete Apple Health dashboard directly to a TRMNL Private Plugin."
        case .homeAssistant:
            return "Publish a Health Snapshot sensor to an existing Home Assistant instance."
        case .selfHostedBridge:
            return "Send rings through your own bridge service before they reach TRMNL."
        }
    }

    var requirements: String {
        switch self {
        case .directTRMNL:
            return "Best for most people. You need a TRMNL Private Plugin configured with a webhook strategy."
        case .homeAssistant:
            return "Choose this if your TRMNL dashboard already reads activity data from Home Assistant."
        case .selfHostedBridge:
            return "Choose this if you already run the included bridge and want to keep its server-side workflow."
        }
    }

    var setupSteps: [SetupStep] {
        switch self {
        case .directTRMNL:
            return [
                SetupStep(
                    systemImage: "rectangle.connected.to.line.below",
                    title: "Open your Private Plugin",
                    detail: "In TRMNL, use a Private Plugin with a webhook strategy. Copy the generated webhook URL."
                ),
                SetupStep(
                    systemImage: "link",
                    title: "Paste the webhook URL",
                    detail: "Return here, paste the TRMNL webhook URL, and connect once so the app can save it securely."
                ),
                SetupStep(
                    systemImage: "clock.arrow.circlepath",
                    title: "Automate one sync action",
                    detail: "In Shortcuts, run this app's Sync Apple Health action whenever you want to refresh your TRMNL display."
                )
            ]

        case .homeAssistant:
            return [
                SetupStep(
                    systemImage: "person.badge.key.fill",
                    title: "Create an access token",
                    detail: "In Home Assistant, open your profile and create a long-lived access token for this app."
                ),
                SetupStep(
                    systemImage: "house.fill",
                    title: "Connect your instance",
                    detail: "Paste your Home Assistant URL and token here. The app publishes a Health Snapshot sensor."
                ),
                SetupStep(
                    systemImage: "rectangle.connected.to.line.below",
                    title: "Use the snapshot in TRMNL",
                    detail: "Keep your existing Home Assistant integration and select the Health Snapshot sensor for the dashboard."
                )
            ]

        case .selfHostedBridge:
            return [
                SetupStep(
                    systemImage: "server.rack",
                    title: "Deploy the bridge",
                    detail: "Run the included bridge service and keep its setup token handy."
                ),
                SetupStep(
                    systemImage: "link",
                    title: "Enter both URLs",
                    detail: "Paste the bridge URL, setup token, and the webhook URL from your TRMNL Private Plugin."
                ),
                SetupStep(
                    systemImage: "checkmark.shield.fill",
                    title: "Register this device",
                    detail: "Connect once. The bridge stores the TRMNL destination and accepts future activity snapshots."
                )
            ]
        }
    }

    var finishTitle: String {
        switch self {
        case .directTRMNL:
            return "Add one Shortcut action"
        case .homeAssistant:
            return "Finish in Home Assistant"
        case .selfHostedBridge:
            return "Your bridge is ready"
        }
    }

    var finishDetail: String {
        switch self {
        case .directTRMNL:
            return "Run Sync Apple Health whenever you want your TRMNL screen, activity rings, and daily metrics to refresh."
        case .homeAssistant:
            return "Your Health Snapshot sensor is the source of truth. Keep the Home Assistant automation or TRMNL recipe you already use."
        case .selfHostedBridge:
            return "The app now publishes HealthKit snapshots to your bridge. You can sync manually or from Shortcuts."
        }
    }
}

struct DestinationIllustration: View {
    let destination: SyncDestination

    var body: some View {
        HStack(spacing: 12) {
            IllustrationSymbol(systemImage: "iphone", tint: .pink)
            Image(systemName: "arrow.right")
                .font(.headline)
                .foregroundStyle(.secondary)
            IllustrationSymbol(systemImage: destination.systemImage, tint: destination.tint)
            Image(systemName: "arrow.right")
                .font(.headline)
                .foregroundStyle(.secondary)
            IllustrationSymbol(systemImage: "rectangle", tint: .primary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Health data flows from your iPhone through \(destination.displayName) to your TRMNL display")
    }
}

struct ShortcutIllustration: View {
    var body: some View {
        HStack(spacing: 12) {
            IllustrationSymbol(systemImage: "clock.badge.checkmark", tint: .indigo)
            Image(systemName: "arrow.right")
                .font(.headline)
                .foregroundStyle(.secondary)
            VStack(spacing: 8) {
                ShortcutActionRow(systemImage: "heart.circle.fill", title: "Sync Apple Health")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("A Shortcuts automation runs Sync Apple Health")
    }
}

struct SetupStepRow: View {
    let step: SetupStep
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: step.systemImage)
                .font(.title3)
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(step.title)
                    .font(.headline)
                Text(step.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct DestinationCard: View {
    let destination: SyncDestination
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: destination.systemImage)
                    .font(.title2)
                    .foregroundStyle(destination.tint)
                    .frame(width: 42, height: 42)
                    .background(destination.tint.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(destination.displayName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(destination.shortSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 4)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? destination.tint : .secondary)
            }
            .padding()
            .background(.background, in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? destination.tint : Color.secondary.opacity(0.2), lineWidth: isSelected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct IllustrationSymbol: View {
    let systemImage: String
    let tint: Color

    var body: some View {
        Image(systemName: systemImage)
            .font(.title2)
            .foregroundStyle(tint)
            .frame(width: 58, height: 58)
            .background(tint.opacity(0.12), in: Circle())
    }
}

private struct ShortcutActionRow: View {
    let systemImage: String
    let title: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
    }
}
