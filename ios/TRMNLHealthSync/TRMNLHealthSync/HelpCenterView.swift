import SwiftUI

struct HelpCenterView: View {
    let startSetup: () -> Void

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: "heart.text.square.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.pink)
                    Text("TRMNL Health Sync")
                        .font(.title2.bold())
                    Text("A practical guide to setup, automations, destinations, privacy, and the activity snapshot sent to your display.")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)

                Button(action: startSetup) {
                    Label("Open Step-by-Step Setup", systemImage: "list.number")
                }
            }

            Section("Learn") {
                NavigationLink {
                    StartHereView()
                } label: {
                    Label("Start Here: Pick a Route", systemImage: "signpost.right.and.left")
                }

                NavigationLink {
                    HowItWorksView()
                } label: {
                    Label("How It Works", systemImage: "arrow.triangle.branch")
                }

                NavigationLink {
                    ShortcutsHelpView()
                } label: {
                    Label("Shortcuts Automation", systemImage: "clock.badge.checkmark")
                }

                NavigationLink {
                    FAQView()
                } label: {
                    Label("Frequently Asked Questions", systemImage: "questionmark.bubble")
                }
            }

            Section("Destination Guides") {
                ForEach(SyncDestination.allCases) { destination in
                    NavigationLink {
                        DestinationHelpView(destination: destination)
                    } label: {
                        DestinationGuideLabel(destination: destination)
                    }
                }
            }

            Section("Setup Resources") {
                Link(destination: URL(string: "https://help.trmnl.com/en/articles/9510536-private-plugins")!) {
                    Label("TRMNL Private Plugins", systemImage: "safari")
                }
                Link(destination: URL(string: "https://www.hacs.xyz/docs/faq/custom_repositories/")!) {
                    Label("HACS Custom Repositories", systemImage: "safari")
                }
                Link(destination: URL(string: "https://companion.home-assistant.io/docs/integrations/siri-shortcuts/")!) {
                    Label("Home Assistant Shortcuts", systemImage: "safari")
                }
            }
        }
        .navigationTitle("Help")
    }
}

private struct StartHereView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeader(
                    systemImage: "signpost.right.and.left",
                    title: "Start Here",
                    detail: "Pick the simplest route that matches what you already run. You can switch later without changing your Health data.",
                    tint: .green
                )

                VStack(alignment: .leading, spacing: 14) {
                    Text("Recommended order")
                        .font(.headline)
                    Text("Start with TRMNL Direct unless you already have a reason to place Home Assistant or your own server in the middle.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .cardStyle()

                ForEach(SyncDestination.allCases) { destination in
                    NavigationLink {
                        DestinationHelpView(destination: destination)
                    } label: {
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: destination.systemImage)
                                .font(.title2)
                                .foregroundStyle(destination.tint)
                                .frame(width: 42, height: 42)
                                .background(destination.tint.opacity(0.12), in: Circle())

                            VStack(alignment: .leading, spacing: 5) {
                                Text(destination.displayName)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text(destination.difficulty.badgeText)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(destination.tint)
                                Text(destination.difficulty.detail)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.leading)
                            }

                            Spacer(minLength: 4)

                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                    .cardStyle()
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Every route ends the same way")
                        .font(.headline)
                    NumberedHelpStep(
                        number: 1,
                        title: "Connect once",
                        detail: "Choose a destination in Settings, enter its required connection details, and approve Apple Health access.",
                        tint: .green
                    )
                    NumberedHelpStep(
                        number: 2,
                        title: "Run Sync Now",
                        detail: "Use the Activity tab to confirm the first snapshot reaches your destination.",
                        tint: .green
                    )
                    NumberedHelpStep(
                        number: 3,
                        title: "Add an optional automation",
                        detail: "Use the Sync Apple Health Shortcuts action for scheduled refreshes.",
                        tint: .green
                    )
                }
                .cardStyle()
            }
            .padding()
        }
        .navigationTitle("Start Here")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(uiColor: .systemGroupedBackground))
    }
}

private struct HowItWorksView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeader(
                    systemImage: "arrow.triangle.branch",
                    title: "How It Works",
                    detail: "One small snapshot moves from Apple Health to your TRMNL dashboard. You choose the route.",
                    tint: .blue
                )

                VStack(alignment: .leading, spacing: 16) {
                    NumberedHelpStep(
                        number: 1,
                        title: "Apple Health stays the source of truth",
                        detail: "With your permission, the app reads today's rings, steps, distance, flights, latest heart rate, sleep, and latest workout from Apple Health.",
                        tint: .blue
                    )
                    NumberedHelpStep(
                        number: 2,
                        title: "The app builds one compact snapshot",
                        detail: "It sends only the values needed by the display, not your complete Health history.",
                        tint: .blue
                    )
                    NumberedHelpStep(
                        number: 3,
                        title: "Your chosen destination receives it",
                        detail: "TRMNL Direct sends the snapshot straight to TRMNL. Home Assistant and Self-Hosted Bridge add a system you control in the middle.",
                        tint: .blue
                    )
                    NumberedHelpStep(
                        number: 4,
                        title: "TRMNL renders the e-ink layout",
                        detail: "The dashboard template turns the snapshot into rings and daily metrics, then your TRMNL device refreshes on its normal schedule.",
                        tint: .blue
                    )
                }
                .cardStyle()

                VStack(alignment: .leading, spacing: 12) {
                    Text("Ways to refresh")
                        .font(.headline)
                    Text("Use Sync Now in the Activity tab, open the app to refresh in the foreground, or run the Sync Apple Health Shortcuts action on a schedule.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .cardStyle()
            }
            .padding()
        }
        .navigationTitle("How It Works")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(uiColor: .systemGroupedBackground))
    }
}

private struct ShortcutsHelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeader(
                    systemImage: "clock.badge.checkmark",
                    title: "Shortcuts Automation",
                    detail: "Refresh your full Apple Health dashboard on TRMNL with one automation.",
                    tint: .indigo
                )

                ShortcutIllustration()
                    .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 18) {
                    NumberedHelpStep(
                        number: 1,
                        title: "Confirm manual sync works first",
                        detail: "In TRMNL Health Sync, open Activity and tap Sync Now. Set up your destination before automating it.",
                        tint: .indigo
                    )
                    NumberedHelpStep(
                        number: 2,
                        title: "Open Shortcuts",
                        detail: "On your iPhone, open Apple's Shortcuts app and tap Automation at the bottom of the screen.",
                        tint: .indigo
                    )
                    NumberedHelpStep(
                        number: 3,
                        title: "Create a personal automation",
                        detail: "Tap the plus button, then choose a trigger. Time of Day is a simple starting point. Pick the schedule you want.",
                        tint: .indigo
                    )
                    NumberedHelpStep(
                        number: 4,
                        title: "Choose Run Immediately",
                        detail: "If Shortcuts offers a Run Immediately option, select it so scheduled refreshes do not wait for confirmation.",
                        tint: .indigo
                    )
                    NumberedHelpStep(
                        number: 5,
                        title: "Add one app action",
                        detail: "Tap New Blank Automation or Add Action. Search for TRMNL Health Sync and choose Sync Apple Health.",
                        tint: .indigo
                    )
                    NumberedHelpStep(
                        number: 6,
                        title: "Run a test",
                        detail: "Use the play button once. The action should report the selected route, such as Synced Apple Health via Home Assistant.",
                        tint: .indigo
                    )
                }
                .cardStyle()

                VStack(alignment: .leading, spacing: 10) {
                    Text("Good starting schedule")
                        .font(.headline)
                    Text("A few refreshes across the day are usually enough for an e-ink dashboard. Add more only if you actually want them.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .cardStyle()
            }
            .padding()
        }
        .navigationTitle("Shortcuts")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(uiColor: .systemGroupedBackground))
    }
}

private struct DestinationHelpView: View {
    let destination: SyncDestination

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeader(
                    systemImage: destination.systemImage,
                    title: destination.displayName,
                    detail: destination.requirements,
                    tint: destination.tint
                )

                DifficultyBanner(destination: destination)

                DestinationIllustration(destination: destination)
                    .frame(maxWidth: .infinity)

                ForEach(destination.detailedSetupSections) { section in
                    VStack(alignment: .leading, spacing: 14) {
                        Text(section.title)
                            .font(.headline)

                        if let detail = section.detail {
                            Text(detail)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        ForEach(Array(section.steps.enumerated()), id: \.element.id) { index, step in
                            NumberedHelpStep(
                                number: index + 1,
                                title: step.title,
                                detail: step.detail,
                                tint: destination.tint
                            )
                        }
                    }
                    .cardStyle()
                }
            }
            .padding()
        }
        .navigationTitle(destination.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(uiColor: .systemGroupedBackground))
    }
}

private struct DestinationGuideLabel: View {
    let destination: SyncDestination

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(destination.displayName)
                Text(destination.difficulty.badgeText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: destination.systemImage)
        }
    }
}

private struct DifficultyBanner: View {
    let destination: SyncDestination

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "gauge.with.dots.needle.33percent")
                .font(.title3)
                .foregroundStyle(destination.tint)

            VStack(alignment: .leading, spacing: 4) {
                Text(destination.difficulty.badgeText)
                    .font(.headline)
                Text(destination.difficulty.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .cardStyle()
    }
}

private struct NumberedHelpStep: View {
    let number: Int
    let title: String
    let detail: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number.formatted())
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(tint, in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct FAQView: View {
    var body: some View {
        List {
            FAQRow(
                question: "Do I need another iPhone app?",
                answer: "No. TRMNL Health Sync reads the Apple Health values used by the dashboard and sends the complete compact snapshot directly to your Private Plugin."
            )
            FAQRow(
                question: "Which destination should I choose?",
                answer: "Choose TRMNL Direct unless you already use Home Assistant or intentionally want to maintain your own bridge server. Open Start Here: Pick a Route for the ranked comparison."
            )
            FAQRow(
                question: "Is my full Health history uploaded?",
                answer: "No. The app reads today's activity totals and publishes a compact snapshot for the display."
            )
            FAQRow(
                question: "Can I sync without Shortcuts?",
                answer: "Yes. Use Sync Now in the Activity tab. Shortcuts simply makes refreshes automatic."
            )
            FAQRow(
                question: "Where can I change the connection?",
                answer: "Open Settings, choose a destination, update its fields, and connect again."
            )
            FAQRow(
                question: "Why can’t Home Assistant find Health Snapshot?",
                answer: "Connect the iPhone app to Home Assistant first and tap Sync Now once. The bridge integration cannot select Health Snapshot until the app publishes that sensor."
            )
            FAQRow(
                question: "Do I need to edit Liquid markup?",
                answer: "Ordinary users should install the published Apple Health Recipe. Liquid markup editing is only a developer fallback before the Recipe is published."
            )
        }
        .navigationTitle("FAQ")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct FAQRow: View {
    let question: String
    let answer: String

    var body: some View {
        DisclosureGroup(question) {
            Text(answer)
                .foregroundStyle(.secondary)
                .padding(.vertical, 8)
        }
    }
}
