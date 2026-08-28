import SwiftUI

struct FileListView: View {
    @Binding var files: [PrintFileItem]
    @Binding var selectedIDs: Set<UUID>
    let missingIDs: Set<UUID>
    let onMove: (IndexSet, Int) -> Void
    @State private var draggedItem: PrintFileItem?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("待打印文件")
                    .font(.headline)
                Spacer()
                Text("\(files.filter(\.isSelected).count)/\(files.count) 已选择")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(10)

            if files.isEmpty {
                ContentUnavailableView(
                    "暂无文件",
                    systemImage: "doc.on.doc",
                    description: Text("请选择一个源文件夹，或刷新文件夹。")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: $selectedIDs) {
                    ForEach(files.indices, id: \.self) { index in
                        let file = files[index]
                        FileRow(
                            file: $files[index],
                            isMissing: missingIDs.contains(file.id)
                        )
                        .tag(file.id)
                        .onDrag {
                            draggedItem = file
                            return NSItemProvider(object: file.id.uuidString as NSString)
                        }
                        .onDrop(
                            of: [.text],
                            delegate: FileDropDelegate(
                                target: file,
                                files: $files,
                                draggedItem: $draggedItem
                            )
                        )
                        .contextMenu {
                            Button("在 Finder 中显示") {
                                NSWorkspace.shared.activateFileViewerSelecting([file.url])
                            }
                        }
                    }
                    .onMove(perform: onMove)
                }
                .listStyle(.inset)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

private struct FileDropDelegate: DropDelegate {
    let target: PrintFileItem
    @Binding var files: [PrintFileItem]
    @Binding var draggedItem: PrintFileItem?

    func dropEntered(info: DropInfo) {
        guard let draggedItem else { return }
        guard draggedItem.id != target.id else { return }
        guard
            let from = files.firstIndex(where: { $0.id == draggedItem.id }),
            let to = files.firstIndex(where: { $0.id == target.id })
        else {
            return
        }

        withAnimation {
            files.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedItem = nil
        return true
    }
}

private struct FileRow: View {
    @Binding var file: PrintFileItem
    let isMissing: Bool

    var body: some View {
        HStack(spacing: 10) {
            Toggle("", isOn: $file.isSelected)
                .labelsHidden()
                .toggleStyle(.checkbox)

            Image(systemName: file.type?.systemImageName ?? "doc")
                .foregroundStyle(file.type?.isImage == true ? .purple : .blue)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 3) {
                Text(file.fileName)
                    .lineLimit(1)
                    .truncationMode(.middle)
                HStack(spacing: 8) {
                    Text(file.fileSizeText)
                    Text(file.modifiedAtText)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            StatusBadge(status: file.status)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 3)
        .listRowBackground(
            isMissing ? Color.red.opacity(0.16) : Color.clear
        )
    }
}

struct StatusBadge: View {
    let status: PrintJobStatus

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)
            Text(status.title)
        }
        .font(.caption)
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(tint.opacity(0.12), in: Capsule())
    }

    private var iconName: String {
        switch status {
        case .queued: "clock"
        case .printing: "printer"
        case .success: "checkmark.circle"
        case .failed: "xmark.circle"
        case .skipped: "forward.circle"
        }
    }

    private var tint: Color {
        switch status {
        case .queued: .secondary
        case .printing: .blue
        case .success: .green
        case .failed: .red
        case .skipped: .orange
        }
    }
}
