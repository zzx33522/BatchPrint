import Foundation
import SwiftUI

@MainActor
final class PrintPresetStore: ObservableObject {
    @Published var preset: PrintPreset {
        didSet {
            save()
        }
    }

    private let defaults: UserDefaults
    private let storageKey = "BatchPrint.preset.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if
            let data = defaults.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode(PrintPreset.self, from: data)
        {
            var migrated = decoded
            if !migrated.enabledTypes.contains(SupportedFileType.doc.rawValue) {
                migrated.enabledTypes.insert(SupportedFileType.doc.rawValue)
            }
            self.preset = migrated
        } else {
            self.preset = PrintPreset()
        }
    }

    func reset() {
        preset = PrintPreset()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(preset) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
