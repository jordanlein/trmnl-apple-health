import SwiftUI

struct ContentView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        NavigationStack {
            Form {
                Section("Destination") {
                    Picker("Sync through", selection: $model.syncDestinationInput) {
                        ForEach(SyncDestination.allCases) { destination in
                            Text(destination.displayName).tag(destination)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                switch model.syncDestinationInput {
                case .homeAssistant:
                    Section("Home Assistant") {
                        TextField("Instance URL", text: $model.instanceURLInput)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                            .autocorrectionDisabled()

                        SecureField("Long-lived access token", text: $model.accessTokenInput)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                        TextField("Device label", text: $model.deviceNameInput)
                    }

                case .selfHostedBridge:
                    Section("Self-Hosted Bridge") {
                        TextField("Bridge URL", text: $model.bridgeURLInput)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                            .autocorrectionDisabled()

                        SecureField("Setup token", text: $model.bridgeSetupTokenInput)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                        TextField("TRMNL webhook URL", text: $model.trmnlWebhookURLInput)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                            .autocorrectionDisabled()

                        TextField("Device label", text: $model.deviceNameInput)
                    }
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
                    .disabled(model.isBusy)

                    Button("Reset Local Configuration", role: .destructive) {
                        model.resetConfiguration()
                    }
                }

                Section("Status") {
                    Text(model.statusMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let snapshot = model.lastSnapshot {
                    Section("Today") {
                        LabeledContent("Steps", value: "\(snapshot.steps)")
                        LabeledContent("Distance", value: String(format: "%.2f mi", snapshot.distanceMiles))
                        LabeledContent("Flights", value: "\(snapshot.flightsClimbed)")
                        LabeledContent("Move", value: "\(snapshot.moveKilocalories) / \(snapshot.moveGoalKilocalories) kcal")
                        LabeledContent("Exercise", value: "\(snapshot.exerciseMinutes) / \(snapshot.exerciseGoalMinutes) min")
                        LabeledContent("Stand", value: "\(snapshot.standHours) / \(snapshot.standGoalHours) h")
                    }
                }
            }
            .navigationTitle("TRMNL Health Sync")
        }
    }
}
