import Foundation

public enum PlanValidator {
    public static func parse(_ content: String) throws -> ModelPlan {
        guard content.utf8.count <= 100_000 else { throw RuleError.invalidPlan("模型计划过大。") }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let json: String
        if trimmed.hasPrefix("```"), let firstNewline = trimmed.firstIndex(of: "\n"),
           let closing = trimmed.range(of: "```", options: .backwards), closing.lowerBound > firstNewline {
            json = String(trimmed[trimmed.index(after: firstNewline)..<closing.lowerBound])
        } else { json = trimmed }
        guard let data = json.data(using: .utf8),
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw RuleError.invalidPlan("模型没有返回 JSON 对象。")
        }
        let required: Set<String> = ["schema_version", "policy_hash", "inventory_id", "actions", "clarifications"]
        guard Set(object.keys) == required, let actions = object["actions"] as? [[String: Any]],
              actions.count <= 50 else { throw RuleError.invalidPlan("计划字段或操作数量不符合协议。") }
        let actionKeys: Set<String> = ["rule_id", "file_id", "destination", "reason", "evidence"]
        guard actions.allSatisfy({ Set($0.keys) == actionKeys }) else {
            throw RuleError.invalidPlan("操作包含未知字段或缺少必填字段。")
        }
        return try JSONDecoder().decode(ModelPlan.self, from: data)
    }

    public static func validate(_ plan: ModelPlan, policy: Policy, inventory: Inventory) throws -> [ValidatedAction] {
        guard !inventory.isPartial else { throw RuleError.invalidPlan("扫描不完整，不能生成可执行计划。") }
        guard plan.schemaVersion == 1, plan.policyHash == policy.hash, plan.inventoryID == inventory.id else {
            throw RuleError.invalidPlan("规范或扫描已变化，请重新生成计划。")
        }
        guard plan.actions.count <= 50 else { throw RuleError.invalidPlan("一次最多 50 项操作。") }
        let records = Dictionary(uniqueKeysWithValues: inventory.records.map { ($0.id, $0) })
        var seenFiles: Set<String> = []
        return try plan.actions.map { action in
            guard policy.ruleIDs.contains(action.ruleID) else {
                throw RuleError.invalidPlan("操作引用了不存在的规范条款：\(action.ruleID)")
            }
            guard let record = records[action.fileID] else {
                throw RuleError.invalidPlan("操作引用了不在扫描内的文件。")
            }
            guard seenFiles.insert(action.fileID).inserted else {
                throw RuleError.invalidPlan("同一文件出现多次操作。")
            }
            guard !action.reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !action.evidence.isEmpty, action.evidence.allSatisfy({ !$0.isEmpty }) else {
                throw RuleError.invalidPlan("每项操作都需要原因与证据。")
            }
            let directory = try safeRelativePath(action.destination)
            let source = try safeRelativePath(record.relativePath)
            let destination = try safeRelativePath(directory + "/" + record.name)
            guard destination != source else { throw RuleError.invalidPlan("来源和目标不能相同。") }
            try checkExistingPathComponents(root: inventory.rootURL, relativePath: destination)
            return ValidatedAction(proposal: action, source: record, destinationRelativePath: destination)
        }
    }

    public static func safeRelativePath(_ value: String) throws -> String {
        guard !value.isEmpty, value.utf8.count <= 512, !value.hasPrefix("/"),
              !value.contains("\\"), !value.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains) else {
            throw RuleError.invalidPlan("目标路径必须位于授权目录内。")
        }
        let parts = value.split(separator: "/", omittingEmptySubsequences: false)
        guard !parts.isEmpty, parts.count <= 16,
              parts.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." && !$0.hasPrefix(".") }) else {
            throw RuleError.invalidPlan("路径包含不允许的隐藏项或上级目录。")
        }
        return parts.joined(separator: "/")
    }

    public static func checkExistingPathComponents(root: URL, relativePath: String) throws {
        var current = root
        let fm = FileManager.default
        for component in relativePath.split(separator: "/").dropLast() {
            current.appendPathComponent(String(component), isDirectory: true)
            if fm.fileExists(atPath: current.path) {
                let values = try current.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
                guard values.isDirectory == true, values.isSymbolicLink != true else {
                    throw RuleError.invalidPlan("目标路径包含符号链接或非目录。")
                }
            }
        }
    }
}
