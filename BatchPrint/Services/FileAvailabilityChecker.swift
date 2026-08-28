import AppKit
import Foundation

struct MissingFile: Identifiable {
    let id = UUID()
    let item: PrintFileItem
    let reason: String
}

enum FileAvailabilityChecker {
    static func check(_ items: [PrintFileItem]) -> [MissingFile] {
        items.compactMap { item in
            let exists = FileManager.default.fileExists(atPath: item.url.path)
            guard !exists else { return nil }

            return MissingFile(
                item: item,
                reason: "文件不存在或无法访问"
            )
        }
    }

    static func canOpenExternally(_ url: URL) -> Bool {
        NSWorkspace.shared.urlForApplication(toOpen: url) != nil
    }
}
