import AppKit
import Foundation

enum ExternalDocumentPrinter {
    static func printDocument(at url: URL, preset: PrintPreset) throws {
        guard let applicationURL = NSWorkspace.shared.urlForApplication(toOpen: url) else {
            throw PrintRunnerError.cannotOpenFile(url.lastPathComponent)
        }

        let appName = displayName(for: applicationURL)

        if let script = appleScript(for: appName, fileURL: url, printerName: preset.printerName) {
            let appleScript = NSAppleScript(source: script)
            var error: NSDictionary?
            appleScript?.executeAndReturnError(&error)
            if let error {
                let message = error[NSAppleScript.errorMessage] as? String ?? "未知 AppleScript 错误"
                throw PrintRunnerError.externalPrintFallback("\(url.lastPathComponent)（\(message)）")
            }
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.open([url], withApplicationAt: applicationURL, configuration: configuration)
        throw PrintRunnerError.externalPrintFallback(url.lastPathComponent)
    }

    static func applicationName(for url: URL) -> String? {
        guard let applicationURL = NSWorkspace.shared.urlForApplication(toOpen: url) else {
            return nil
        }
        return displayName(for: applicationURL)
    }

    private static func displayName(for applicationURL: URL) -> String {
        FileManager.default.displayName(atPath: applicationURL.path)
            .replacingOccurrences(of: ".app", with: "")
    }

    private static func appleScript(for appName: String, fileURL: URL, printerName: String?) -> String? {
        let posixPath = fileURL.path.replacingOccurrences(of: "\"", with: "\\\"")

        switch appName.lowercased() {
        case "microsoft word":
            return """
            tell application "Microsoft Word"
                activate
                open POSIX file "\(posixPath)"
                print active document
            end tell
            """
        case "pages":
            return """
            tell application "Pages"
                activate
                open POSIX file "\(posixPath)"
                print front document
            end tell
            """
        case "textedit":
            return """
            tell application "TextEdit"
                activate
                open POSIX file "\(posixPath)"
                print front document
            end tell
            """
        default:
            return nil
        }
    }
}
