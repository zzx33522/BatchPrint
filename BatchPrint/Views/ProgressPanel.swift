import SwiftUI

struct ProgressPanel: View {
    @ObservedObject var runner: PrintJobRunner
    let onStop: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(runner.progress.isRunning ? "正在批量打印" : "打印已结束")
                    .font(.title2.bold())
                Spacer()
                Button("关闭") {
                    onClose()
                }
                .disabled(runner.progress.isRunning)
            }

            ProgressView(value: runner.progress.fractionCompleted) {
                HStack {
                    Text(currentTitle)
                    Spacer()
                    Text("\(runner.progress.currentIndex)/\(runner.progress.total)")
                        .foregroundStyle(.secondary)
                }
            }
            .tint(.blue)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 5) {
                    ForEach(runner.logLines, id: \.self) { line in
                        Text(line)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
            }
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            HStack {
                if runner.progress.isRunning {
                    Button(role: .destructive) {
                        onStop()
                    } label: {
                        Label("停止后续任务", systemImage: "stop.fill")
                    }
                }
                Spacer()
            }
        }
        .padding(20)
    }

    private var currentTitle: String {
        if runner.progress.isRunning {
            return "正在打印：\(runner.progress.currentFileName)"
        }
        return "任务已全部处理"
    }
}
