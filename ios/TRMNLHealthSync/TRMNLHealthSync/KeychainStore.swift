import Foundation
import Security

enum KeychainStore {
    private static let service = "TRMNLHealthSync"

    enum SecretAccount: String {
        case homeAssistantAccessToken = "home_assistant_access_token"
        case selfHostedSetupToken = "self_hosted_setup_token"
        case selfHostedDeviceToken = "self_hosted_device_token"
    }

    static func save(_ token: String, for account: SecretAccount) throws {
        let data = Data(token.utf8)
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account.rawValue,
        ]

        SecItemDelete(query as CFDictionary)

        let attributes: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account.rawValue,
            kSecValueData: data,
        ]

        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }

    static func load(_ account: SecretAccount) -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account.rawValue,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    static func clear(_ account: SecretAccount) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account.rawValue,
        ]
        SecItemDelete(query as CFDictionary)
    }

    static func clearAll() {
        SecretAccount.allCases.forEach { account in
            clear(account)
        }
    }
}

extension KeychainStore.SecretAccount: CaseIterable {}
