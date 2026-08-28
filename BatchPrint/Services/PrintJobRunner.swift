import AppKit
import Foundation
import PDFKit

struct PrintSummary {
    var total: Int
    var succeeded: Int
    var failed: [String]
    var skipped: [String]
}

struct PrintProgress {
    var isRunning = false
    var currentIndex = 0
    var total = 0
    var currentFileName = ""
    var fractionCompleted: Double {
        guard total > 0 else { return 0 }
        return Double(currentIndex) / Double(total)
    }
}

enum PrintRunnerError: LocalizedError {
    case unsupportedFile(String)
    case missingPrinter(String)
    case cannotOpenFile(String)
    case invalidPageRange(String)
    case externalPrintFallback(String)
    case printOperationFailed(String)
    case officeConversionFailed(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .unsupportedFile(let name):
            return "不支持的文件类型：\(name)"
        case .missingPrinter(let name):
            return "找不到打印机：\(name)"
        case .cannotOpenFile(let name):
            return "无法打开文件：\(name)"
        case .invalidPageRange(let value):
            return "页面范围格式不正确：\(value)"
        case .externalPrintFallback(let name):
            return "已打开 \(name)，但该应用不支持自动打印，请手动确认。"
        case .printOperationFailed(let name):
            return "系统未能完成打印作业：\(name)"
        case .officeConversionFailed(let message):
            return "Word 转 PDF 失败：\(message)"
        case .cancelled:
            return "打印已停止"
        }
    }
}

@MainActor
final class PrintJobRunner: ObservableObject {
    @Published var progress = PrintProgress()
    @Published var logLines: [String] = []

    private var cancelled = false
    private var onStatusChange: ((UUID, PrintJobStatus) -> Void)?

    func cancel() {
        cancelled = true
        appendLog("收到停止请求，正在结束后续任务…")
    }

    func reset() {
        cancelled = false
        progress = PrintProgress()
        logLines.removeAll()
    }

    func run(
        items: [PrintFileItem],
        preset: PrintPreset,
        onStatusChange: @escaping (UUID, PrintJobStatus) -> Void
    ) async -> PrintSummary {
        reset()
        self.onStatusChange = onStatusChange

        let queue = items.filter(\.isSelected)
        progress.total = queue.count
        progress.isRunning = true

        var succeeded = 0
        var failures: [String] = []
        var skipped: [String] = []

        appendLog("打印队列共 \(queue.count) 个文件。")

        for (index, item) in queue.enumerated() {
            if cancelled {
                appendLog("已停止。")
                skipped.append(item.fileName)
                updateStatus(for: item.id, status: .skipped("用户停止"))
                continue
            }

            progress.currentIndex = index + 1
            progress.currentFileName = item.fileName
            updateStatus(for: item.id, status: .printing)
            appendLog("正在打印第 \(index + 1)/\(queue.count) 个文件：\(item.fileName)")

            do {
                try await printFile(at: item.url, preset: preset)
                succeeded += 1
                updateStatus(for: item.id, status: .success)
                appendLog("成功：\(item.fileName)")
            } catch {
                let message = error.localizedDescription
                failures.append("\(item.fileName)：\(message)")
                updateStatus(for: item.id, status: .failed(message))
                appendLog("失败：\(item.fileName) — \(message)")
            }

            await Task.yield()
        }

        progress.isRunning = false
        progress.currentFileName = ""

        let summary = PrintSummary(
            total: queue.count,
            succeeded: succeeded,
            failed: failures,
            skipped: skipped
        )
        appendLog("完成：成功 \(summary.succeeded) 个，失败 \(summary.failed.count) 个，跳过 \(summary.skipped.count) 个。")
        return summary
    }

    private func updateStatus(for id: UUID, status: PrintJobStatus) {
        onStatusChange?(id, status)
    }

    private func appendLog(_ message: String) {
        let time = Date().formatted(date: .omitted, time: .standard)
        logLines.append("[\(time)] \(message)")
    }

    private func printFile(at url: URL, preset: PrintPreset) async throws {
        let ext = url.pathExtension.lowercased()
        guard let type = SupportedFileType(rawValue: ext) else {
            throw PrintRunnerError.unsupportedFile(url.lastPathComponent)
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            throw PrintRunnerError.cannotOpenFile(url.lastPathComponent)
        }

        switch type {
        case .pdf:
            try printPDF(at: url, preset: preset)
        case .jpg, .png, .tiff:
            try printImage(at: url, preset: preset)
        case .doc, .docx:
            try await printWordDocument(at: url, preset: preset)
        }
    }

    private func printWordDocument(at url: URL, preset: PrintPreset) async throws {
        let appName = ExternalDocumentPrinter.applicationName(for: url)?.lowercased() ?? ""

        if ["microsoft word", "pages", "textedit"].contains(appName) {
            appendLog("使用 \(appName) 直接打印：\(url.lastPathComponent)")
            try ExternalDocumentPrinter.printDocument(at: url, preset: preset)
            return
        }

        let pdfURL: URL
        do {
            appendLog("正在将 Word 文档转换为 PDF：\(url.lastPathComponent)")
            pdfURL = try await OfficePDFConverter.convertToPDF(sourceURL: url)
        } catch {
            appendLog("Word 转 PDF 失败，将退回 RTF 打印：\(error.localizedDescription)")
            try await WordDocumentPrinter.printDocument(at: url, preset: preset)
            return
        }

        if let convertedDocument = PDFDocument(url: pdfURL) {
            appendLog("PDF 转换完成：\(convertedDocument.pageCount) 页，提取文字 \(convertedDocument.string?.count ?? 0) 字符")
        }

        defer {
            try? FileManager.default.removeItem(at: pdfURL)
        }

        appendLog("开始打印转换后的 PDF：\(url.lastPathComponent)")
        try printPDF(at: pdfURL, preset: preset)
    }

    private func makePrintInfo(preset: PrintPreset) throws -> NSPrintInfo {
        guard let printInfo = NSPrintInfo.shared.copy() as? NSPrintInfo else {
            throw PrintRunnerError.missingPrinter(preset.printerName ?? "默认打印机")
        }

        if let printerName = preset.printerName, let printer = NSPrinter(name: printerName) {
            printInfo.printer = printer
        }

        printInfo.orientation = preset.orientation == .portrait ? .portrait : .landscape
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .fit
        printInfo.isHorizontallyCentered = true
        printInfo.isVerticallyCentered = true

        let paper = paperSize(for: preset)
        printInfo.paperSize = paper

        let attributes = printInfo.dictionary()
        attributes[NSPrintInfo.AttributeKey.copies] = NSNumber(value: preset.copies)

        if preset.scaling == .percentage {
            attributes[NSPrintInfo.AttributeKey.scalingFactor] = NSNumber(value: preset.scalePercentage / 100.0)
        }

        switch preset.colorMode {
        case .color:
            attributes[NSPrintInfo.AttributeKey("NSPrintColorMode")] = NSNumber(value: 1)
        case .monochrome:
            attributes[NSPrintInfo.AttributeKey("NSPrintColorMode")] = NSNumber(value: 2)
        case .grayscale:
            attributes[NSPrintInfo.AttributeKey("NSPrintColorMode")] = NSNumber(value: 3)
        }

        let duplexValue: NSNumber
        switch preset.duplex {
        case .none:
            duplexValue = NSNumber(value: 0)
        case .longEdge:
            duplexValue = NSNumber(value: 1)
        case .shortEdge:
            duplexValue = NSNumber(value: 2)
        }
        attributes[NSPrintInfo.AttributeKey("NSPrintDuplex")] = duplexValue

        return printInfo
    }

    private func paperSize(for preset: PrintPreset) -> NSSize {
        switch preset.paperSize {
        case .a4:
            return NSSize(width: 595.28, height: 841.89)
        case .letter:
            return NSSize(width: 612, height: 792)
        case .a3:
            return NSSize(width: 841.89, height: 1190.55)
        case .legal:
            return NSSize(width: 612, height: 1008)
        case .b5:
            return NSSize(width: 498.9, height: 708.66)
        case .custom:
            let width = max(100, preset.customPaperWidthMM) * 72.0 / 25.4
            let height = max(100, preset.customPaperHeightMM) * 72.0 / 25.4
            return NSSize(width: width, height: height)
        }
    }

    private func printPDF(at url: URL, preset: PrintPreset) throws {
        guard let document = PDFDocument(url: url) else {
            throw PrintRunnerError.cannotOpenFile(url.lastPathComponent)
        }

        let pageIndices = try selectedPageIndices(for: document, pageRange: preset.pageRange)
        let documentToPrint: PDFDocument

        if pageIndices.count == document.pageCount {
            documentToPrint = document
        } else {
            let subset = PDFDocument()
            for index in pageIndices {
                if let page = document.page(at: index) {
                    subset.insert(page, at: subset.pageCount)
                }
            }
            guard subset.pageCount > 0 else {
                throw PrintRunnerError.invalidPageRange(preset.pageRange.customText)
            }
            documentToPrint = subset
        }

        let info = try makePrintInfo(preset: preset)
        guard let operation = documentToPrint.printOperation(
            for: info,
            scalingMode: preset.scaling == .fit ? .pageScaleDownToFit : .pageScaleNone,
            autoRotate: true
        ) else {
            throw PrintRunnerError.cannotOpenFile(url.lastPathComponent)
        }
        try runOperation(operation, fileName: url.lastPathComponent)
    }

    private func selectedPageIndices(for document: PDFDocument, pageRange: PageRange) throws -> [Int] {
        if pageRange.isAllPages {
            return Array(0..<document.pageCount)
        }

        let text = pageRange.customText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw PrintRunnerError.invalidPageRange(text)
        }

        var indices = Set<Int>()
        for component in text.split(separator: ",") {
            let value = String(component).trimmingCharacters(in: .whitespaces)
            if value.contains("-") {
                let parts = value.split(separator: "-", maxSplits: 1)
                guard
                    parts.count == 2,
                    let start = Int(parts[0].trimmingCharacters(in: .whitespaces)),
                    let end = Int(parts[1].trimmingCharacters(in: .whitespaces)),
                    start >= 1,
                    end >= start
                else {
                    throw PrintRunnerError.invalidPageRange(value)
                }
                indices.formUnion((start...end).map { $0 - 1 })
            } else {
                guard let page = Int(value), page >= 1 else {
                    throw PrintRunnerError.invalidPageRange(value)
                }
                indices.insert(page - 1)
            }
        }

        let validIndices = indices.filter { $0 >= 0 && $0 < document.pageCount }.sorted()
        guard !validIndices.isEmpty else {
            throw PrintRunnerError.invalidPageRange(text)
        }
        return validIndices
    }

    private func printImage(at url: URL, preset: PrintPreset) throws {
        guard let image = NSImage(contentsOf: url) else {
            throw PrintRunnerError.cannotOpenFile(url.lastPathComponent)
        }

        let info = try makePrintInfo(preset: preset)
        let imageView = NSImageView(frame: NSRect(origin: .zero, size: image.size))
        imageView.image = image
        imageView.imageScaling = preset.scaling == .fit ? .scaleProportionallyDown : .scaleAxesIndependently

        let operation = NSPrintOperation(view: imageView, printInfo: info)
        try runOperation(operation, fileName: url.lastPathComponent)
    }

    private func runOperation(_ operation: NSPrintOperation, fileName: String) throws {
        operation.showsPrintPanel = false
        operation.showsProgressPanel = false
        let success = operation.run()
        if !success {
            throw PrintRunnerError.printOperationFailed(fileName)
        }
    }
}
