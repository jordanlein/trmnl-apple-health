import SwiftUI

struct ContentView: View {
    @ObservedObject var model: AppModel
    @State private var selectedTab = AppTab.activity
    @State private var isShowingOnboarding = !OnboardingStore.hasCompletedOnboarding

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                ActivityDashboardView(
                    model: model,
                    startSetup: showOnboarding
                )
            }
            .tabItem {
                Label("Activity", systemImage: "heart.circle.fill")
            }
            .tag(AppTab.activity)

            NavigationStack {
                SettingsView(
                    model: model,
                    startSetup: showOnboarding
                )
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape.fill")
            }
            .tag(AppTab.settings)

            NavigationStack {
                HelpCenterView(startSetup: showOnboarding)
            }
            .tabItem {
                Label("Help", systemImage: "questionmark.circle.fill")
            }
            .tag(AppTab.help)
        }
        .fullScreenCover(isPresented: $isShowingOnboarding) {
            OnboardingView(model: model) {
                OnboardingStore.markCompleted()
                isShowingOnboarding = false
            }
        }
    }

    private func showOnboarding() {
        isShowingOnboarding = true
    }
}

private enum AppTab {
    case activity
    case settings
    case help
}
