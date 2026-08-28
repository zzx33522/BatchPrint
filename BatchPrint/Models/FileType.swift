import Foundation
import UniformTypeIdentifiers

enum SupportedFileType: String, CaseIterable, Codable, Identifiable {
    case pdf
    case doc
    case docx
    case jpg
    case png
    case tiff

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pdf: "PDF"
        case .doc: "Word 97-2003 文档"
        case .docx: "Word 文档"
        case .jpg: "JPEG 图片"
        case .png: "PNG 图片"
        case .tiff: "TIFF 图片"
        }
    }

    var fileExtension: String { rawValue }

    var utType: UTType? {
        switch self {
        case .pdf: .pdf
        case .doc: UTType(filenameExtension: "doc")
        case .docx: UTType(filenameExtension: "docx")
        case .jpg: .jpeg
        case .png: .png
        case .tiff: .tiff
        }
    }

    var isImage: Bool {
        self == .jpg || self == .png || self == .tiff
    }

    var systemImageName: String {
        switch self {
        case .pdf: "doc.richtext"
        case .doc: "doc.text"
        case .docx: "doc.text"
        case .jpg, .png, .tiff: "photo"
        }
    }
}
