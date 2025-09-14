import Foundation
import Security

class KeychainManager {
    static let shared = KeychainManager()

    private init() {}

    private let service = "com.betteruntis.ios"

    // MARK: - Generic Keychain Operations
    private func save(key: String, data: Data) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]

        // Delete any existing item first
        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    private func load(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        return status == errSecSuccess ? result as? Data : nil
    }

    private func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    // MARK: - User Credentials Management
    func saveUserCredentials(userId: String, user: String, key: String) -> Bool {
        let credentials = UserCredentials(user: user, key: key)

        do {
            let data = try JSONEncoder().encode(credentials)
            return save(key: "user_credentials_\(userId)", data: data)
        } catch {
            print("Failed to encode user credentials: \(error)")
            return false
        }
    }

    func loadUserCredentials(userId: String) -> UserCredentials? {
        guard let data = load(key: "user_credentials_\(userId)") else {
            return nil
        }

        do {
            return try JSONDecoder().decode(UserCredentials.self, from: data)
        } catch {
            print("Failed to decode user credentials: \(error)")
            return nil
        }
    }

    func deleteUserCredentials(userId: String) -> Bool {
        return delete(key: "user_credentials_\(userId)")
    }

    // MARK: - App Shared Secret Management
    func saveAppSharedSecret(schoolId: String, secret: String) -> Bool {
        guard let data = secret.data(using: .utf8) else { return false }
        return save(key: "app_shared_secret_\(schoolId)", data: data)
    }

    func loadAppSharedSecret(schoolId: String) -> String? {
        guard let data = load(key: "app_shared_secret_\(schoolId)") else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    func deleteAppSharedSecret(schoolId: String) -> Bool {
        return delete(key: "app_shared_secret_\(schoolId)")
    }

    // MARK: - Generic String Storage
    func save(string: String, forKey key: String) -> Bool {
        guard let data = string.data(using: .utf8) else { return false }
        return save(key: key, data: data)
    }

    func loadString(forKey key: String) -> String? {
        guard let data = load(key: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func deleteString(forKey key: String) -> Bool {
        return delete(key: key)
    }
}

// MARK: - Supporting Types
struct UserCredentials: Codable {
    let user: String
    let key: String
}