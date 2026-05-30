import Foundation

enum AppConfigurationStore {
    private static let defaultsKey = "TRMNLHealthSync.configuration"

    static func load() -> AppConfiguration {
        guard
            let data = UserDefaults.standard.data(forKey: defaultsKey),
            let decoded = try? JSONDecoder().decode(AppConfiguration.self, from: data)
        else {
            return AppConfiguration()
        }
        return decoded
    }

    static func save(_ configuration: AppConfiguration) throws {
        let data = try JSONEncoder().encode(configuration)
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }
}
