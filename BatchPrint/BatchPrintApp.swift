import SwiftUI

@main
struct BatchPrintApp: App {
    @StateObject private var store = PrintPresetStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 960, minHeight: 620)
        }
        .windowStyle(.automatic)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("选择文件夹…") {
                    NotificationCenter.default.post(name: .batchPrintSelectFolder, object: nil)
                }
                .keyboardShortcut("o", modifiers: [.command])
            }
        }
    }
}

extension Notification.Name {
    static let batchPrintSelectFolder = Notification.Name("BatchPrintSelectFolder")
}
