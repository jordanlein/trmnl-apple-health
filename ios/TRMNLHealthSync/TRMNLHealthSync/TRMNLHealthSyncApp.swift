import SwiftUI
import UIKit

@main
struct TRMNLHealthSyncApp: App {
    @StateObject private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let selectedColor = UIColor { traits in
            traits.userInterfaceStyle == .dark ? .white : .black
        }
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        [
            appearance.stackedLayoutAppearance,
            appearance.inlineLayoutAppearance,
            appearance.compactInlineLayoutAppearance,
        ].forEach { itemAppearance in
            itemAppearance.selected.iconColor = selectedColor
            itemAppearance.selected.titleTextAttributes = [
                .foregroundColor: selectedColor,
            ]
        }

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
                .task {
                    await model.bootstrap()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    guard newPhase == .active else { return }
                    Task {
                        await model.handleSceneBecameActive()
                    }
                }
        }
    }
}
