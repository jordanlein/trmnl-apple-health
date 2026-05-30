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
                        Label(destination.displayName, systemImage: destination.systemImage)
                    }
                }
            }

            Section("TRMNL Resources") {
                Link(destination: URL(string: "https://help.trmnl.com/en/articles/9510536-private-plugins")!) {
                    Label("Private Plugins", systemImage: "safari")
                }
                Link(destination: URL(string: "https://help.trmnl.com/en/articles/10671186-liquid-101")!) {
                    Label("Liquid 101", systemImage: "safari")
                }
            }
        }
        .navigationTitle("Help")
    }
}

private struct HowItWorksView: View {
    var body: some View {
        HelpArticleView(
            title: "How It Works",
            systemImage: "arrow.triangle.branch",
            sections: [
                HelpSection(
                    title: "What the app reads",
                    detail: "With your permission, the app reads today's rings, steps, distance, flights, heart rate, sleep, and latest workout from Apple Health."
                ),
                HelpSection(
                    title: "What the app sends",
                    detail: "The app publishes a compact activity snapshot. It does not upload your complete Health history."
                ),
                HelpSection(
                    title: "Where the snapshot goes",
                    detail: "You choose one destination: directly to a TRMNL Private Plugin webhook, to Home Assistant as a sensor, or through your self-hosted bridge."
                ),
                HelpSection(
                    title: "When it refreshes",
                    detail: "Use Sync Now, background HealthKit updates when available, or the Sync Apple Health Shortcuts action."
                )
            ]
        )
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
                    SetupStepRow(
                        step: SetupStep(
                            systemImage: "clock.badge.plus",
                            title: "Choose a trigger",
                            detail: "In Shortcuts, create an automation using a time, location, focus, or another trigger that fits your day."
                        ),
                        tint: .indigo
                    )
                    SetupStepRow(
                        step: SetupStep(
                            systemImage: "rectangle.connected.to.line.below",
                            title: "Add one app action",
                            detail: "Choose Sync Apple Health from TRMNL Health Sync."
                        ),
                        tint: .indigo
                    )
                    SetupStepRow(
                        step: SetupStep(
                            systemImage: "heart.circle.fill",
                            title: "Let it run automatically",
                            detail: "Turn off Ask Before Running if you want scheduled dashboard refreshes without extra taps."
                        ),
                        tint: .indigo
                    )
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

                DestinationIllustration(destination: destination)
                    .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 18) {
                    ForEach(destination.setupSteps) { step in
                        SetupStepRow(step: step, tint: destination.tint)
                    }
                }
                .cardStyle()
            }
            .padding()
        }
        .navigationTitle(destination.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(uiColor: .systemGroupedBackground))
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
                answer: "TRMNL Direct is the simplest option for most people. Keep Home Assistant or the self-hosted bridge if your dashboard already depends on those workflows."
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

private struct HelpArticleView: View {
    let title: String
    let systemImage: String
    let sections: [HelpSection]

    var body: some View {
        List {
            Section {
                Image(systemName: systemImage)
                    .font(.largeTitle)
                    .foregroundStyle(.tint)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
            }

            ForEach(sections) { section in
                Section(section.title) {
                    Text(section.detail)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct HelpSection: Identifiable {
    let title: String
    let detail: String

    var id: String { title }
}
