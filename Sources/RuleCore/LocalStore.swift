import Foundation
import Security

public struct SavedState: Codable, Sendable {
    public var policies: [Policy] = []
    public var selectedRootPath: String? = nil
    public var modelConfig: ModelConfig = ModelConfig()
    public var journal: [JournalEntry] = []

    public init() {}
    public var activePolicy: Policy? { policies.last }
}

public struct LocalStore: Sendable {
    public let fileURL: URL

    public init(fileURL: URL? = nil) {
        if let fileURL { self.fileURL = fileURL; return }
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        self.fileURL = support.appendingPathComponent("MacRuleManager/state.json")
    }

    public func load() throws -> SavedState {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return SavedState() }
        return try JSONDecoder().decode(SavedState.self, from: Data(contentsOf: fileURL))
    }

    public func save(_ state: SavedState) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        if fm.fileExists(atPath: fileURL.path),
           (try? JSONDecoder().decode(SavedState.self, from: Data(contentsOf: fileURL))) == nil {
            let backup = fileURL.deletingLastPathComponent()
                .appendingPathComponent("state.corrupt-\(UUID().uuidString).json")
            try fm.copyItem(at: fileURL, to: backup)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(state).write(to: fileURL, options: .atomic)
    }
}

public enum CredentialStore {
    private static let service = "org.macrulemanager.api-key"

    public static func save(_ key: String, provider: Provider) throws {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider.rawValue
        ]
        let updateStatus = SecItemUpdate(base as CFDictionary,
                                         [kSecValueData as String: Data(key.utf8)] as CFDictionary)
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else {
            throw RuleError.invalidConfiguration("无法更新 macOS 钥匙串中的密钥（\(updateStatus)）。")
        }
        var query = base
        query[kSecValueData as String] = Data(key.utf8)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw RuleError.invalidConfiguration("无法保存密钥到 macOS 钥匙串（\(status)）。")
        }
    }

    public static func read(provider: Provider) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw RuleError.invalidConfiguration("无法从 macOS 钥匙串读取密钥（\(status)）。")
        }
        return String(data: data, encoding: .utf8)
    }
}
