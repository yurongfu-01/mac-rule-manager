import CryptoKit
import Foundation

public enum RuleError: LocalizedError {
    case invalidPolicy(String)
    case invalidConfiguration(String)
    case invalidPlan(String)
    case fileChanged(String)
    case conflict(String)

    public var errorDescription: String? {
        switch self {
        case .invalidPolicy(let value), .invalidConfiguration(let value),
             .invalidPlan(let value), .fileChanged(let value), .conflict(let value): value
        }
    }
}

public struct Policy: Codable, Sendable {
    public let text: String
    public let version: Int
    public let savedAt: Date
    public let hash: String
    public let ruleIDs: [String]

    public init(text: String, version: Int) throws {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { throw RuleError.invalidPolicy("请先写入自己的管理规范。") }
        let ids = Self.extractRuleIDs(from: normalized)
        guard !ids.isEmpty else { throw RuleError.invalidPolicy("每条可执行规范需以 R001: 这样的编号开头。") }
        guard Set(ids).count == ids.count else { throw RuleError.invalidPolicy("规范编号不能重复。") }
        self.text = normalized
        self.version = version
        self.savedAt = Date()
        self.hash = "sha256:" + SHA256.hash(data: Data(normalized.utf8)).map { String(format: "%02x", $0) }.joined()
        self.ruleIDs = ids
    }

    private static func extractRuleIDs(from text: String) -> [String] {
        text.split(separator: "\n").compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard let colon = trimmed.firstIndex(of: ":") else { return nil }
            let id = String(trimmed[..<colon])
            guard id.count >= 2, id.first == "R", id.dropFirst().allSatisfy(\.isNumber) else { return nil }
            return id
        }
    }
}

public enum Provider: String, CaseIterable, Codable, Identifiable, Sendable {
    case openAI = "OpenAI"
    case deepSeek = "DeepSeek"
    case mimo = "小米 MiMo"

    public var id: String { rawValue }
    public var defaultEndpoint: String {
        switch self {
        case .openAI: "https://api.openai.com/v1/chat/completions"
        case .deepSeek: "https://api.deepseek.com/chat/completions"
        case .mimo: "https://api.xiaomimimo.com/v1/chat/completions"
        }
    }
}

public struct ModelConfig: Codable, Sendable {
    public var provider: Provider = .openAI
    public var model: String = ""
    public var endpoint: String = Provider.openAI.defaultEndpoint
    public var includeNames: Bool = false

    public init() {}

    public func validatedURL() throws -> URL {
        guard !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw RuleError.invalidConfiguration("请填写模型标识。")
        }
        guard let url = URL(string: endpoint), url.scheme == "https", url.host != nil,
              url.user == nil, url.password == nil, url.query == nil, url.fragment == nil else {
            throw RuleError.invalidConfiguration("接口地址必须是完整的 HTTPS URL，且不能包含账户或查询参数。")
        }
        return url
    }
}

public struct FileRecord: Codable, Identifiable, Sendable {
    public let id: String
    public let relativePath: String
    public let size: Int64
    public let modifiedAt: Date
    public let fileNumber: UInt64

    public var name: String { URL(fileURLWithPath: relativePath).lastPathComponent }
    public var fileExtension: String { URL(fileURLWithPath: relativePath).pathExtension.lowercased() }
    public var ageDays: Int { max(0, Int(Date().timeIntervalSince(modifiedAt) / 86_400)) }
}

public struct Inventory: Codable, Sendable {
    public let id: String
    public let rootPath: String
    public let scannedAt: Date
    public let records: [FileRecord]
    public let skipped: Int
    public let errors: [String]
    public let isPartial: Bool

    public var rootURL: URL { URL(fileURLWithPath: rootPath, isDirectory: true) }
}

public struct ProposedAction: Codable, Identifiable, Sendable {
    public let ruleID: String
    public let fileID: String
    public let destination: String
    public let reason: String
    public let evidence: [String]
    public var id: String { fileID + "|" + ruleID }

    enum CodingKeys: String, CodingKey {
        case ruleID = "rule_id", fileID = "file_id", destination, reason, evidence
    }
}

public struct ModelPlan: Codable, Sendable {
    public let schemaVersion: Int
    public let policyHash: String
    public let inventoryID: String
    public let actions: [ProposedAction]
    public let clarifications: [String]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version", policyHash = "policy_hash"
        case inventoryID = "inventory_id", actions, clarifications
    }
}

public struct ValidatedAction: Identifiable, Sendable {
    public let proposal: ProposedAction
    public let source: FileRecord
    public let destinationRelativePath: String
    public var id: String { proposal.id }
}

public struct JournalEntry: Codable, Identifiable, Sendable {
    public enum Status: String, Codable, Sendable { case pending, verified, failed, undone }
    public let id: UUID
    public let planID: UUID
    public let policyHash: String
    public let rootPath: String
    public let sourcePath: String
    public let destinationPath: String
    public let expectedSize: Int64
    public let expectedModifiedAt: Date
    public let expectedFileNumber: UInt64
    public var status: Status
    public var message: String
    public let createdAt: Date

    public init(planID: UUID, policyHash: String, rootPath: String,
                sourcePath: String, destinationPath: String,
                expectedSize: Int64, expectedModifiedAt: Date, expectedFileNumber: UInt64) {
        self.id = UUID()
        self.planID = planID
        self.policyHash = policyHash
        self.rootPath = rootPath
        self.sourcePath = sourcePath
        self.destinationPath = destinationPath
        self.expectedSize = expectedSize
        self.expectedModifiedAt = expectedModifiedAt
        self.expectedFileNumber = expectedFileNumber
        self.status = .pending
        self.message = "已记录操作意图，尚待核验"
        self.createdAt = Date()
    }
}
