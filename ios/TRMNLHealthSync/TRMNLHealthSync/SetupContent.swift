import SwiftUI

struct SetupStep: Identifiable {
    let systemImage: String
    let title: String
    let detail: String

    var id: String { title }
}

struct SetupGuideSection: Identifiable {
    let title: String
    let detail: String?
    let steps: [SetupStep]

    var id: String { title }
}

struct DestinationDifficulty {
    let rank: Int
    let label: String
    let detail: String

    var badgeText: String {
        "\(rank) of 3 • \(label)"
    }
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
            return "Recommended for most people. Install the Apple Health Recipe in TRMNL, copy one webhook URL, and paste it into this app."
        case .homeAssistant:
            return "Choose this if you already run Home Assistant and want the Health Snapshot sensor available there before it reaches TRMNL."
        case .selfHostedBridge:
            return "Choose this if you are comfortable deploying and maintaining a small Docker service on your own server."
        }
    }

    var difficulty: DestinationDifficulty {
        switch self {
        case .directTRMNL:
            return DestinationDifficulty(
                rank: 1,
                label: "Easy",
                detail: "Recommended. No server or Home Assistant instance is required."
            )
        case .homeAssistant:
            return DestinationDifficulty(
                rank: 2,
                label: "Intermediate",
                detail: "Requires an existing Home Assistant instance, HACS, and a one-time sensor mapping."
            )
        case .selfHostedBridge:
            return DestinationDifficulty(
                rank: 3,
                label: "Advanced",
                detail: "Requires Docker, a server you maintain, and basic troubleshooting comfort."
            )
        }
    }

    var setupSteps: [SetupStep] {
        switch self {
        case .directTRMNL:
            return [
                SetupStep(
                    systemImage: "square.and.arrow.down",
                    title: "Install the Apple Health Recipe",
                    detail: "In TRMNL, install the published Apple Health Recipe. Use a webhook Private Plugin only as a developer fallback before the Recipe is available."
                ),
                SetupStep(
                    systemImage: "link",
                    title: "Copy and paste one URL",
                    detail: "Copy the Recipe webhook URL, paste it here, and connect once so the app can save it securely."
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
                    systemImage: "shippingbox.fill",
                    title: "Install the HACS bridge",
                    detail: "Download TRMNL Apple Health Bridge through HACS and restart Home Assistant."
                ),
                SetupStep(
                    systemImage: "person.badge.key.fill",
                    title: "Publish Health Snapshot",
                    detail: "Create a long-lived Home Assistant token, paste it here with your URL, and connect. The app publishes a Health Snapshot sensor."
                ),
                SetupStep(
                    systemImage: "rectangle.connected.to.line.below",
                    title: "Map the sensor to TRMNL",
                    detail: "Add TRMNL Health Bridge in Home Assistant, select Health Snapshot, and paste your TRMNL Recipe webhook URL."
                )
            ]

        case .selfHostedBridge:
            return [
                SetupStep(
                    systemImage: "server.rack",
                    title: "Deploy the bridge",
                    detail: "Run the included Docker bridge service on a server you maintain and keep its setup token handy."
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

    var detailedSetupSections: [SetupGuideSection] {
        switch self {
        case .directTRMNL:
            return [
                SetupGuideSection(
                    title: "Before you begin",
                    detail: "This is the best route for almost everyone. You need the TRMNL Health Sync app, a TRMNL account, and a TRMNL device.",
                    steps: [
                        SetupStep(
                            systemImage: "checkmark.circle",
                            title: "Use the published Recipe when available",
                            detail: "In the TRMNL web app, open Plugins, scroll to Recipes, search for Apple Health, and tap Install. Installed Recipes receive future template improvements automatically."
                        ),
                        SetupStep(
                            systemImage: "hammer",
                            title: "Use a Private Plugin only as a developer fallback",
                            detail: "If the Recipe has not been published yet, create a Private Plugin with the Webhook strategy, paste the bundled markup, and save it. TRMNL says Private Plugin creation requires the Developer add-on or a BYOD license."
                        )
                    ]
                ),
                SetupGuideSection(
                    title: "Connect the iPhone app",
                    detail: "The webhook URL tells this app which TRMNL dashboard instance should receive your Health snapshot.",
                    steps: [
                        SetupStep(
                            systemImage: "doc.on.doc",
                            title: "Copy the webhook URL from TRMNL",
                            detail: "Open the installed Recipe or your Private Plugin settings and copy its webhook URL. Keep this URL private: anyone who has it could send data to that dashboard."
                        ),
                        SetupStep(
                            systemImage: "iphone",
                            title: "Choose TRMNL Direct",
                            detail: "In this app, open Settings, set Sync through to TRMNL Direct, and paste the webhook URL. The device label is only a friendly name."
                        ),
                        SetupStep(
                            systemImage: "heart.circle",
                            title: "Connect and approve Health access",
                            detail: "Tap Connect TRMNL & Sync. When iOS asks, allow access to the Health categories used by the dashboard."
                        )
                    ]
                ),
                SetupGuideSection(
                    title: "Confirm and automate",
                    detail: "The first sync should render a dashboard preview in TRMNL before your physical display refreshes.",
                    steps: [
                        SetupStep(
                            systemImage: "rectangle",
                            title: "Check the TRMNL preview",
                            detail: "Open the plugin settings page in TRMNL. Your latest screen preview should show rings and metrics. If it is blank, tap Sync Now in this app, then use Force Refresh in TRMNL."
                        ),
                        SetupStep(
                            systemImage: "clock.badge.checkmark",
                            title: "Add the optional automation",
                            detail: "Follow the Shortcuts Automation guide in the Learn section. Add this app's Sync Apple Health action to a personal automation for predictable refreshes."
                        )
                    ]
                )
            ]

        case .homeAssistant:
            return [
                SetupGuideSection(
                    title: "Before you begin",
                    detail: "This route is for people who already use Home Assistant. It adds Home Assistant between the iPhone app and TRMNL.",
                    steps: [
                        SetupStep(
                            systemImage: "house",
                            title: "Confirm Home Assistant is reachable",
                            detail: "On your iPhone, open your Home Assistant URL in Safari while connected to your usual network. A local URL such as http://homeassistant.local:8123 or your configured remote URL is fine."
                        ),
                        SetupStep(
                            systemImage: "rectangle.connected.to.line.below",
                            title: "Create the TRMNL dashboard first",
                            detail: "Install the Apple Health Recipe in TRMNL, or create the Webhook Private Plugin developer fallback. Copy its webhook URL for the final mapping step."
                        )
                    ]
                ),
                SetupGuideSection(
                    title: "Install the Home Assistant bridge",
                    detail: "HACS downloads the custom integration. Home Assistant must restart before it can load the new component.",
                    steps: [
                        SetupStep(
                            systemImage: "shippingbox",
                            title: "Open HACS",
                            detail: "In Home Assistant, open HACS. Use the three-dot menu in the upper-right corner and choose Custom repositories."
                        ),
                        SetupStep(
                            systemImage: "link",
                            title: "Add the custom repository",
                            detail: "Paste https://github.com/jordanleinberger/trmnl-apple-health, choose Integration as the repository type, and tap Add."
                        ),
                        SetupStep(
                            systemImage: "arrow.down.circle",
                            title: "Download TRMNL Apple Health Bridge",
                            detail: "Open TRMNL Apple Health Bridge in HACS and download it. When Home Assistant reports Restart required, submit that repair to restart Home Assistant."
                        )
                    ]
                ),
                SetupGuideSection(
                    title: "Publish the iPhone sensor",
                    detail: "Do this before adding the bridge integration. The bridge cannot select a Health Snapshot sensor until the app creates it.",
                    steps: [
                        SetupStep(
                            systemImage: "person.badge.key",
                            title: "Create a long-lived access token",
                            detail: "In Home Assistant, open your user profile. At the bottom of the profile page, create a Long-Lived Access Token and copy it immediately. Home Assistant does not show the token again."
                        ),
                        SetupStep(
                            systemImage: "iphone",
                            title: "Connect this app to Home Assistant",
                            detail: "In this app, choose Home Assistant. Enter your Home Assistant URL, paste the token, and tap Connect Home Assistant & Sync. Approve Health access if iOS asks."
                        ),
                        SetupStep(
                            systemImage: "waveform.path.ecg",
                            title: "Wait for Health Snapshot",
                            detail: "The app registers a sensor named Health Snapshot plus supporting sensors. If the next step cannot find it, return here and tap Sync Now once."
                        )
                    ]
                ),
                SetupGuideSection(
                    title: "Map the sensor to TRMNL",
                    detail: "This one-time step teaches Home Assistant which iPhone sensor should be forwarded to which TRMNL webhook.",
                    steps: [
                        SetupStep(
                            systemImage: "plus.circle",
                            title: "Add TRMNL Health Bridge",
                            detail: "In Home Assistant, open Settings, then Devices & services, then Add integration. Search for TRMNL Health Bridge."
                        ),
                        SetupStep(
                            systemImage: "sensor",
                            title: "Choose Health Snapshot",
                            detail: "Select the sensor whose friendly name is Health Snapshot. Paste the TRMNL webhook URL you copied earlier, then save."
                        ),
                        SetupStep(
                            systemImage: "checkmark.circle",
                            title: "Confirm the first display push",
                            detail: "Tap Sync Now in this app. The Home Assistant integration will forward the snapshot to TRMNL. Check the TRMNL plugin preview or use Force Refresh if needed."
                        )
                    ]
                )
            ]

        case .selfHostedBridge:
            return [
                SetupGuideSection(
                    title: "Before you begin",
                    detail: "This route is intended for advanced users who want to operate their own bridge. You need Docker Compose and a machine that stays online.",
                    steps: [
                        SetupStep(
                            systemImage: "server.rack",
                            title: "Choose a server",
                            detail: "Use a Raspberry Pi, mini PC, NAS, home server, or VPS that your iPhone can reach. The bridge listens on port 8421 by default."
                        ),
                        SetupStep(
                            systemImage: "rectangle.connected.to.line.below",
                            title: "Create the TRMNL dashboard",
                            detail: "Install the Apple Health Recipe in TRMNL, or create the Webhook Private Plugin developer fallback. Copy its webhook URL."
                        )
                    ]
                ),
                SetupGuideSection(
                    title: "Deploy the bridge",
                    detail: "The repository includes a Docker Compose example and a small local status dashboard.",
                    steps: [
                        SetupStep(
                            systemImage: "doc.on.doc",
                            title: "Copy the compose example",
                            detail: "On your server, clone the GitHub repository and copy docker-compose.example.yml to docker-compose.yml."
                        ),
                        SetupStep(
                            systemImage: "key",
                            title: "Choose a private setup token",
                            detail: "Replace TRMNL_HEALTH_SETUP_TOKEN=change-me with a long private value. This token is used once to pair the app with your bridge."
                        ),
                        SetupStep(
                            systemImage: "terminal",
                            title: "Start the service",
                            detail: "From the repository folder, run docker compose up --build -d. Then open http://YOUR-SERVER:8421 in a browser to confirm the bridge dashboard loads."
                        )
                    ]
                ),
                SetupGuideSection(
                    title: "Pair the iPhone app",
                    detail: "The bridge stores the latest snapshot and pushes the compact payload onward to TRMNL.",
                    steps: [
                        SetupStep(
                            systemImage: "iphone",
                            title: "Choose Self-Hosted Bridge",
                            detail: "In this app, enter the bridge URL, setup token, and TRMNL webhook URL. The bridge URL usually looks like http://192.168.x.x:8421."
                        ),
                        SetupStep(
                            systemImage: "checkmark.shield",
                            title: "Connect and approve Health access",
                            detail: "Tap Connect Bridge & Sync. The bridge returns a device token that this app stores securely for later updates."
                        ),
                        SetupStep(
                            systemImage: "rectangle",
                            title: "Confirm both dashboards",
                            detail: "Check the bridge's local dashboard first, then the TRMNL plugin preview. If the bridge has data but TRMNL is blank, verify the TRMNL webhook URL."
                        )
                    ]
                ),
                SetupGuideSection(
                    title: "Keep it healthy",
                    detail: "Unlike the direct route, you own this server and its updates.",
                    steps: [
                        SetupStep(
                            systemImage: "arrow.triangle.2.circlepath",
                            title: "Automate iPhone refreshes",
                            detail: "Follow the Shortcuts Automation guide in the Learn section so the app publishes fresh snapshots throughout the day."
                        ),
                        SetupStep(
                            systemImage: "wrench.and.screwdriver",
                            title: "Maintain the server",
                            detail: "Keep Docker running, back up the data volume if you care about history, and pull repository updates when bridge fixes are published."
                        )
                    ]
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
                    Text(destination.difficulty.badgeText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(destination.tint)
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
