import SwiftUI

struct OnboardingView: View {
    @ObservedObject var model: AppModel
    let onFinish: () -> Void
    @State private var page = 0

    private let pageCount = 5

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ProgressView(value: Double(page + 1), total: Double(pageCount))
                    .padding(.horizontal)

                TabView(selection: $page) {
                    WelcomePage()
                        .tag(0)

                    DestinationPickerPage(selection: $model.syncDestinationInput)
                        .tag(1)

                    DestinationGuidePage(destination: model.syncDestinationInput)
                        .id(model.syncDestinationInput)
                        .tag(2)

                    ConnectionPage(model: model)
                        .id(model.syncDestinationInput)
                        .tag(3)

                    CompletionPage(destination: model.syncDestinationInput)
                        .tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                Divider()

                HStack {
                    if page > 0 {
                        Button("Back") {
                            withAnimation {
                                page -= 1
                            }
                        }
                    }

                    Spacer()

                    Text("\(page + 1) of \(pageCount)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button(page == pageCount - 1 ? "Finish" : "Continue") {
                        if page == pageCount - 1 {
                            onFinish()
                        } else {
                            withAnimation {
                                page += 1
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
            .navigationTitle("Set Up Health Sync")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Not Now", action: onFinish)
                }
            }
        }
    }
}

private struct WelcomePage: View {
    var body: some View {
        OnboardingPage {
            Spacer(minLength: 24)

            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 74))
                .foregroundStyle(.pink.gradient)

            VStack(spacing: 10) {
                Text("Put your rings on TRMNL")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)

                Text("TRMNL Health Sync reads your daily Apple Health activity and publishes a compact snapshot wherever your display already expects it.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 16) {
                WelcomeFeature(systemImage: "heart.circle.fill", title: "Complete dashboard", detail: "Rings, steps, distance, flights, heart rate, sleep, and your latest workout.")
                WelcomeFeature(systemImage: "arrow.triangle.2.circlepath", title: "Three destinations", detail: "TRMNL Direct, Home Assistant, or your self-hosted bridge.")
                WelcomeFeature(systemImage: "clock.badge.checkmark", title: "Shortcuts ready", detail: "Refresh the whole TRMNL dashboard with one app action.")
            }
            .padding(.top, 12)

            Spacer(minLength: 24)
        }
    }
}

private struct WelcomeFeature: View {
    let systemImage: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct DestinationPickerPage: View {
    @Binding var selection: SyncDestination

    var body: some View {
        OnboardingPage {
            PageHeader(
                systemImage: "point.3.connected.trianglepath.dotted",
                title: "Choose your route",
                detail: "The app adapts its instructions and connection form to match the way your TRMNL dashboard receives data."
            )

            ForEach(SyncDestination.allCases) { destination in
                DestinationCard(
                    destination: destination,
                    isSelected: selection == destination
                ) {
                    selection = destination
                }
            }
        }
    }
}

private struct DestinationGuidePage: View {
    let destination: SyncDestination

    var body: some View {
        OnboardingPage {
            PageHeader(
                systemImage: destination.systemImage,
                title: destination.displayName,
                detail: destination.requirements,
                tint: destination.tint
            )

            OnboardingDifficultyBanner(destination: destination)

            DestinationIllustration(destination: destination)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)

            VStack(alignment: .leading, spacing: 6) {
                Text("Follow these steps in order")
                    .font(.headline)
                Text("This is the complete setup path for \(destination.displayName). You can pause here and reopen the same guide later from Help.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

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
                        OnboardingNumberedStep(
                            number: index + 1,
                            step: step,
                            tint: destination.tint
                        )
                    }
                }
                .padding()
                .background(.background, in: RoundedRectangle(cornerRadius: 18))
            }
        }
    }
}

private struct ConnectionPage: View {
    @ObservedObject var model: AppModel

    var body: some View {
        OnboardingPage {
            PageHeader(
                systemImage: "link.badge.plus",
                title: "Connect once",
                detail: "Enter the details for \(model.syncDestinationInput.displayName). The app saves the connection locally for future manual and Shortcut syncs.",
                tint: model.syncDestinationInput.tint
            )

            VStack(alignment: .leading, spacing: 14) {
                Text("What you'll enter")
                    .font(.headline)

                ForEach(model.syncDestinationInput.connectionFieldTips) { tip in
                    SetupStepRow(step: tip, tint: model.syncDestinationInput.tint)
                }
            }
            .padding()
            .background(.background, in: RoundedRectangle(cornerRadius: 18))

            VStack(alignment: .leading, spacing: 14) {
                DestinationConfigurationFields(model: model)
                    .textFieldStyle(.roundedBorder)

                Button {
                    Task {
                        await model.connectAndSync()
                    }
                } label: {
                    if model.isBusy {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text(model.syncDestinationInput.connectButtonLabel)
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(model.isBusy)

                Label(model.statusMessage, systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(.background, in: RoundedRectangle(cornerRadius: 18))

            Text("You can continue reading the guide before connecting. The same fields remain available later in Settings.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

private struct OnboardingDifficultyBanner: View {
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 18))
    }
}

private struct OnboardingNumberedStep: View {
    let number: Int
    let step: SetupStep
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number.formatted())
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(tint, in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(step.title)
                    .font(.subheadline.weight(.semibold))
                Text(step.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct CompletionPage: View {
    let destination: SyncDestination

    var body: some View {
        OnboardingPage {
            PageHeader(
                systemImage: "checkmark.circle.fill",
                title: destination.finishTitle,
                detail: destination.finishDetail,
                tint: .green
            )

            if destination == .directTRMNL {
                ShortcutIllustration()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)

                VStack(alignment: .leading, spacing: 18) {
                    SetupStepRow(
                        step: SetupStep(
                            systemImage: "clock.badge.plus",
                            title: "Create or open an automation",
                            detail: "In Shortcuts, use the time, location, or focus trigger you already prefer."
                        ),
                        tint: .indigo
                    )
                    SetupStepRow(
                        step: SetupStep(
                            systemImage: "rectangle.connected.to.line.below",
                            title: "Add TRMNL Health Sync",
                            detail: "Choose this app's Sync Apple Health action. It refreshes the full dashboard."
                        ),
                        tint: .indigo
                    )
                    SetupStepRow(
                        step: SetupStep(
                            systemImage: "heart.circle.fill",
                            title: "Run automatically",
                            detail: "Turn off Ask Before Running if you want your TRMNL display to refresh quietly on schedule."
                        ),
                        tint: .indigo
                    )
                }
                .padding()
                .background(.background, in: RoundedRectangle(cornerRadius: 18))
            } else {
                DestinationIllustration(destination: destination)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)

                VStack(alignment: .leading, spacing: 12) {
                    Text("What happens next")
                        .font(.headline)
                    Text(destination.shortSummary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("You can always reopen this guide from Settings or browse the Help tab for a refresher.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(.background, in: RoundedRectangle(cornerRadius: 18))
            }
        }
    }
}

struct PageHeader: View {
    let systemImage: String
    let title: String
    let detail: String
    var tint: Color = .accentColor

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 46))
                .foregroundStyle(tint)
            Text(title)
                .font(.title.bold())
                .multilineTextAlignment(.center)
            Text(detail)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct OnboardingPage<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                content
            }
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }
}
