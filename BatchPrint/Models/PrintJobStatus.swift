import Foundation

enum PrintJobStatus: Equatable {
    case queued
    case printing
    case success
    case failed(String)
    case skipped(String)

    var isFinished: Bool {
        switch self {
        case .success, .failed, .skipped:
            return true
        case .queued, .printing:
            return false
        }
    }

    var title: String {
        switch self {
        case .queued: "排队中"
        case .printing: "正在打印"
        case .success: "成功"
        case .failed: "失败"
        case .skipped: "已跳过"
        }
    }

    var tint: String {
        switch self {
        case .queued: "secondary"
        case .printing: "blue"
        case .success: "green"
        case .failed: "red"
        case .skipped: "orange"
        }
    }
}
