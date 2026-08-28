import Foundation

enum PaperSize: String, CaseIterable, Codable, Identifiable {
    case a4
    case letter
    case a3
    case legal
    case b5
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .a4: "A4"
        case .letter: "Letter"
        case .a3: "A3"
        case .legal: "Legal"
        case .b5: "B5"
        case .custom: "自定义"
        }
    }
}

enum DuplexMode: String, CaseIterable, Codable, Identifiable {
    case none
    case longEdge
    case shortEdge

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: "单面"
        case .longEdge: "双面（长边翻转）"
        case .shortEdge: "双面（短边翻转）"
        }
    }
}

enum ColorMode: String, CaseIterable, Codable, Identifiable {
    case color
    case monochrome
    case grayscale

    var id: String { rawValue }

    var title: String {
        switch self {
        case .color: "彩色"
        case .monochrome: "黑白"
        case .grayscale: "灰度"
        }
    }
}

enum ScalingMode: String, CaseIterable, Codable, Identifiable {
    case fit
    case percentage

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fit: "适合页面"
        case .percentage: "按百分比缩放"
        }
    }
}

enum Orientation: String, CaseIterable, Codable, Identifiable {
    case portrait
    case landscape

    var id: String { rawValue }

    var title: String {
        switch self {
        case .portrait: "纵向"
        case .landscape: "横向"
        }
    }
}

struct PageRange: Equatable, Codable {
    var isAllPages = true
    var customText = ""
}

struct PrintPreset: Codable, Equatable {
    var printerName: String?
    var pageRange = PageRange()
    var copies = 1
    var duplex = DuplexMode.none
    var colorMode = ColorMode.color
    var paperSize = PaperSize.a4
    var customPaperWidthMM = 210.0
    var customPaperHeightMM = 297.0
    var scaling = ScalingMode.fit
    var scalePercentage = 100.0
    var orientation = Orientation.portrait
    var enabledTypes = Set(SupportedFileType.allCases.map(\.rawValue))
}
