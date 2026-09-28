import Foundation

public enum Executor {
    public static func execute(_ action: ValidatedAction, inventory: Inventory, policy: Policy,
                               planID: UUID, record: (JournalEntry) throws -> Void) throws -> JournalEntry {
        let root = inventory.rootURL
        let source = root.appendingPathComponent(action.source.relativePath)
        let destination = root.appendingPathComponent(action.destinationRelativePath)
        try verifyRoot(root)
        try PlanValidator.checkExistingPathComponents(root: root, relativePath: action.source.relativePath)
        try PlanValidator.checkExistingPathComponents(root: root, relativePath: action.destinationRelativePath)
        try verifyFile(source, matches: action.source)
        guard !itemExists(at: destination) else {
            throw RuleError.conflict("目标已存在，不会覆盖：\(destination.lastPathComponent)")
        }

        var entry = JournalEntry(planID: planID, policyHash: policy.hash, rootPath: root.path,
                                 sourcePath: source.path, destinationPath: destination.path,
                                 expectedSize: action.source.size,
                                 expectedModifiedAt: action.source.modifiedAt,
                                 expectedFileNumber: action.source.fileNumber)
        try record(entry)
        do {
            try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try PlanValidator.checkExistingPathComponents(root: root, relativePath: action.destinationRelativePath)
            guard !itemExists(at: destination) else {
                throw RuleError.conflict("目标在执行期间出现，已跳过。")
            }
            try verifyFile(source, matches: action.source)
            try FileManager.default.moveItem(at: source, to: destination)
            let verified = !FileManager.default.fileExists(atPath: source.path) &&
                (try? matchesFile(destination, size: action.source.size,
                                  modifiedAt: action.source.modifiedAt,
                                  fileNumber: action.source.fileNumber)) == true
            entry.status = verified ? .verified : .pending
            entry.message = verified ? "已移动并核验" : "移动后未能核验，请检查目标文件"
        } catch {
            entry.status = .failed
            entry.message = error.localizedDescription
        }
        try record(entry)
        return entry
    }

    public static func undo(_ entry: JournalEntry, record: (JournalEntry) throws -> Void) throws -> JournalEntry {
        guard entry.status == .verified else { throw RuleError.conflict("此操作尚未核验或已经撤销。") }
        let root = URL(fileURLWithPath: entry.rootPath, isDirectory: true)
        let source = URL(fileURLWithPath: entry.sourcePath)
        let destination = URL(fileURLWithPath: entry.destinationPath)
        try verifyRoot(root)
        guard source.path.hasPrefix(root.path + "/"), destination.path.hasPrefix(root.path + "/") else {
            throw RuleError.invalidPlan("历史目标不在授权目录内。")
        }
        let sourceRelative = String(source.path.dropFirst(root.path.count + 1))
        let destinationRelative = String(destination.path.dropFirst(root.path.count + 1))
        try PlanValidator.checkExistingPathComponents(root: root, relativePath: sourceRelative)
        try PlanValidator.checkExistingPathComponents(root: root, relativePath: destinationRelative)
        guard !itemExists(at: source) else {
            throw RuleError.conflict("原位置已有文件，不能覆盖。")
        }
        guard try matchesFile(destination, size: entry.expectedSize,
                              modifiedAt: entry.expectedModifiedAt,
                              fileNumber: entry.expectedFileNumber) else {
            throw RuleError.fileChanged("目标文件已变化，不能撤销。")
        }
        try FileManager.default.moveItem(at: destination, to: source)
        var updated = entry
        let verified = FileManager.default.fileExists(atPath: source.path) &&
            !FileManager.default.fileExists(atPath: destination.path)
        updated.status = verified ? .undone : .pending
        updated.message = verified ? "已撤销并核验" : "撤销后未能核验"
        try record(updated)
        return updated
    }

    public static func reconcile(_ entry: JournalEntry) -> JournalEntry {
        guard entry.status == .pending else { return entry }
        var updated = entry
        let sourceExists = itemExists(at: URL(fileURLWithPath: entry.sourcePath))
        let targetMatches = (try? matchesFile(URL(fileURLWithPath: entry.destinationPath),
                                               size: entry.expectedSize,
                                               modifiedAt: entry.expectedModifiedAt,
                                               fileNumber: entry.expectedFileNumber)) == true
        if !sourceExists && targetMatches {
            updated.status = .verified
            updated.message = "重新核验成功"
        } else if sourceExists && !targetMatches {
            updated.status = .failed
            updated.message = "操作未发生"
        } else {
            updated.message = "状态不明确，请人工检查原位置和目标位置"
        }
        return updated
    }

    private static func verifyRoot(_ root: URL) throws {
        let values = try root.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard values.isDirectory == true, values.isSymbolicLink != true else {
            throw RuleError.fileChanged("授权目录已变化。")
        }
    }

    private static func verifyFile(_ url: URL, matches record: FileRecord) throws {
        guard try matchesFile(url, size: record.size, modifiedAt: record.modifiedAt,
                              fileNumber: record.fileNumber) else {
            throw RuleError.fileChanged("源文件在扫描后已变化，请重新扫描。")
        }
    }

    private static func matchesFile(_ url: URL, size: Int64, modifiedAt: Date,
                                    fileNumber: UInt64) throws -> Bool {
        guard FileManager.default.fileExists(atPath: url.path) else { return false }
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey,
                                                       .fileSizeKey, .contentModificationDateKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true,
              Int64(values.fileSize ?? -1) == size,
              abs((values.contentModificationDate ?? .distantPast).timeIntervalSince(modifiedAt)) < 0.001 else {
            return false
        }
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        let current = (attrs[.systemFileNumber] as? NSNumber)?.uint64Value ?? 0
        return fileNumber != 0 && current == fileNumber
    }

    private static func itemExists(at url: URL) -> Bool {
        var info = stat()
        return lstat(url.path, &info) == 0
    }
}
