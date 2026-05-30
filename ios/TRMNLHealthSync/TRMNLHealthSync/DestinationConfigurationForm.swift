import SwiftUI

struct DestinationConfigurationFields: View {
    @ObservedObject var model: AppModel

    var body: some View {
        switch model.syncDestinationInput {
        case .directTRMNL:
            TextField("TRMNL webhook URL", text: $model.trmnlWebhookURLInput)
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                .autocorrectionDisabled()

            TextField("Device label", text: $model.deviceNameInput)

        case .homeAssistant:
            TextField("Instance URL", text: $model.instanceURLInput)
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                .autocorrectionDisabled()

            SecureField("Long-lived access token", text: $model.accessTokenInput)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            TextField("Device label", text: $model.deviceNameInput)

        case .selfHostedBridge:
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
}
