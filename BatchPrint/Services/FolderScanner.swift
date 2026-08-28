import Foundation

struct FolderScanner {
    enum ScannerError: LocalizedError {
        case notDirectory
        case inaccessible

        var errorDescription: String? {
            switch self {
            case .notDirectory:
                return "所选路径不是文件夹。"
            case .inaccessible:
                return "无法读取该文件夹，请检查访问权限。"
            }
        }
    }

    func scan(
        folder: URL,
        preserving previousItems: [PrintFileItem],
        enabledTypes: Set<String>
    ) throws -> [PrintFileItem] {
        let fileManager = FileManager.default

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: folder.path, isDirectory: &isDirectory) else {
            throw ScannerError.notDirectory
        }
        guard isDirectory.boolValue else {
            throw ScannerError.notDirectory
        }

        let resourceKeys: Set<URLResourceKey> = [
            .isRegularFileKey,
            .fileSizeKey,
            .contentModificationDateKey
        ]

        guard let urls = fileManager.enumerator(
            at: folder,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )?.allObjects as? [URL] else {
            throw ScannerError.inaccessible
        }

        let oldSelection = Dictionary(
            uniqueKeysWithValues: previousItems.map { ($0.url.standardizedFileURL.path, $0.isSelected) }
        )

        let items = urls
            .filter { url in
                let ext = url.pathExtension.lowercased()
                return enabledTypes.contains(ext) && SupportedFileType(rawValue: ext) != nil
            }
            .compactMap { url -> PrintFileItem? in
                let values = try? url.resourceValues(forKeys: resourceKeys)
                guard values?.isRegularFile == true else { return nil }

                let ext = url.pathExtension.lowercased()
                return PrintFileItem(
                    url: url,
                    fileName: url.lastPathComponent,
                    fileExtension: ext,
                    fileSize: Int64(values?.fileSize ?? 0),
                    modifiedAt: values?.contentModificationDate,
                    isSelected: oldSelection[url.standardizedFileURL.path] ?? true
                )
            }
            .sorted {
                $0.fileName.localizedStandardCompare($1.fileName) == .orderedAscending
            }

        return items
    }
}
