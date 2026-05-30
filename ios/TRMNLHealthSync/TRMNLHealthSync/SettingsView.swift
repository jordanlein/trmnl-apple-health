import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel
    let startSetup: () -> Void

    var body: some View {
        Form {
            Section {
                Picker("Sync through", selection: $model.syncDestinationInput) {
                    ForEach(SyncDestination.allCases) { destination in
                        Label(destination.displayName, systemImage: destination.systemImage)
                            .tag(destination)
                    }
                }
            } header: {
                Text("Destination")
            } footer: {
                Text(model.syncDestinationInput.shortSummary)
            }

            Section(model.syncDestinationInput.displayName) {
                DestinationConfigurationFields(model: model)
            }

            Section("Actions") {
                Button(model.syncDestinationInput.connectButtonLabel) {
                    Task {
                        await model.connectAndSync()
                    }
                }
                .disabled(model.isBusy)

                Button("Sync Now") {
                    Task {
                        await model.syncButtonTapped()
                    }
                }
                .disabled(model.isBusy || !model.hasConfiguredDestination)

                Button("Open Setup Guide", action: startSetup)
            }

            Section("Status") {
                Text(model.statusMessage)
                    .foregroundStyle(.secondary)
            }

            if model.syncDestinationInput == .directTRMNL {
                Section("Shortcuts") {
                    Text("After connecting once, add Sync Apple Health from TRMNL Health Sync to a Shortcuts automation. That one action refreshes the complete dashboard.")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button("Reset Local Configuration", role: .destructive) {
                    model.resetConfiguration()
                }
            }
        }
        .navigationTitle("Settings")
    }
}
