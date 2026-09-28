import Foundation

public enum Scanner {
    public static func scan(root: URL, limit: Int = 500) throws -> Inventory {
        let fm = FileManager.default
        let selected = root.standardizedFileURL
        let values = try selected.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard values.isDirectory == true, values.isSymbolicLink != true else {
            throw RuleError.invalidConfiguration("请选择普通目录，不能选择符号链接。")
        }
        let root = selected.resolvingSymlinksInPath().standardizedFileURL
        var errors: [String] = []
        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey, .isPackageKey,
                                         .fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: { url, error in
                errors.append("\(url.lastPathComponent): \(error.localizedDescription)")
                return true
            }
        ) else { throw RuleError.invalidConfiguration("无法扫描所选目录。") }

        var records: [FileRecord] = []
        var skipped = 0
        var partial = false
        while let url = enumerator.nextObject() as? URL {
            if records.count >= limit { partial = true; break }
            do {
                let attributes = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey,
                                                                   .isPackageKey, .fileSizeKey,
                                                                   .contentModificationDateKey])
                if attributes.isSymbolicLink == true || attributes.isPackage == true {
                    enumerator.skipDescendants()
                    skipped += 1
                    continue
                }
                guard attributes.isRegularFile == true else { continue }
                let path = url.standardizedFileURL.path
                guard path.hasPrefix(root.path + "/") else {
                    throw RuleError.invalidConfiguration("扫描结果超出授权目录。")
                }
                let relative = String(path.dropFirst(root.path.count + 1))
                let stat = try fm.attributesOfItem(atPath: url.path)
                let number = (stat[.systemFileNumber] as? NSNumber)?.uint64Value ?? 0
                records.append(FileRecord(
                    id: "F\(records.count + 1)", relativePath: relative,
                    size: Int64(attributes.fileSize ?? 0),
                    modifiedAt: attributes.contentModificationDate ?? .distantPast,
                    fileNumber: number
                ))
            } catch {
                skipped += 1
                errors.append("\(url.lastPathComponent): \(error.localizedDescription)")
            }
        }
        return Inventory(id: UUID().uuidString, rootPath: root.path, scannedAt: Date(),
                         records: records, skipped: skipped, errors: errors,
                         isPartial: partial || !errors.isEmpty)
    }
}
