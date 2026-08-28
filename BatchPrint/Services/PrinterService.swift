import AppKit

enum PrinterService {
    static func availablePrinterNames() -> [String] {
        NSPrinter.printerNames.sorted {
            $0.localizedStandardCompare($1) == .orderedAscending
        }
    }

    static func defaultPrinterName() -> String? {
        NSPrintInfo.shared.printer.name
    }
}
