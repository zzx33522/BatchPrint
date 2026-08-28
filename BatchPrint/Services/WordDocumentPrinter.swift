import AppKit
import Foundation

enum WordDocumentPrinter {
    static func printDocument(at url: URL, preset: PrintPreset) async throws {
        let rtfURL = try await convertToRTF(url)
        defer {
            try? FileManager.default.removeItem(at: rtfURL)
        }

        try await MainActor.run {
            try printRTF(at: rtfURL, originalURL: url, preset: preset)
        }
    }

    private static func convertToRTF(_ url: URL) async throws -> URL {
        try await Task.detached(priority: .userInitiated) {
            let outputURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("rtf")

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/textutil")
            process.arguments = [
                "-convert",
                "rtf",
                "-output",
                outputURL.path,
                url.path
            ]

            let standardError = Pipe()
            process.standardError = standardError
            try process.run()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else {
                let data = standardError.fileHandleForReading.readDataToEndOfFile()
                let message = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? "未知错误"
                throw PrintRunnerError.externalPrintFallback("\(url.lastPathComponent)（\(message)）")
            }

            guard FileManager.default.fileExists(atPath: outputURL.path) else {
                throw PrintRunnerError.cannotOpenFile(url.lastPathComponent)
            }

            return outputURL
        }.value
    }

    @MainActor
    private static func printRTF(at rtfURL: URL, originalURL: URL, preset: PrintPreset) throws {
        let data = try Data(contentsOf: rtfURL)
        let attributedString = try NSAttributedString(
            data: data,
            options: [
                .documentType: NSAttributedString.DocumentType.rtf
            ],
            documentAttributes: nil
        )

        guard let printInfo = NSPrintInfo.shared.copy() as? NSPrintInfo else {
            throw PrintRunnerError.missingPrinter(preset.printerName ?? "默认打印机")
        }

        if let printerName = preset.printerName, let printer = NSPrinter(name: printerName) {
            printInfo.printer = printer
        }

        printInfo.orientation = preset.orientation == .portrait ? .portrait : .landscape
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .automatic
        printInfo.isHorizontallyCentered = true
        printInfo.isVerticallyCentered = true

        let textView = NSTextView(frame: NSRect(origin: .zero, size: printInfo.paperSize))
        textView.textStorage?.setAttributedString(attributedString)
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(
            width: printInfo.paperSize.width,
            height: .greatestFiniteMagnitude
        )
        textView.textContainer?.widthTracksTextView = true
        textView.layoutManager?.ensureLayout(for: textView.textContainer!)

        let operation = NSPrintOperation(view: textView, printInfo: printInfo)
        operation.showsPrintPanel = false
        operation.showsProgressPanel = false

        guard operation.run() else {
            throw PrintRunnerError.printOperationFailed(originalURL.lastPathComponent)
        }
    }
}
