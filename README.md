# BatchPrint

BatchPrint 是一个 macOS 原生批量打印工具，使用 SwiftUI 编写。它从一个源文件夹扫描 PDF、Word 和常见图片文件，按顺序提交打印作业，并在打印前检查文件是否仍然存在。

## 功能概览

- 选择源文件夹并递归扫描 `.pdf`、`.doc`、`.docx`、`.jpg`、`.png`、`.tiff` 文件。
- 文件列表展示名称、大小、修改时间和状态。
- 支持勾选、全选/反选、拖拽排序。
- 自动获取系统打印机列表，保存并恢复打印预设。
- 支持页面范围、份数、单双面、色彩模式、纸张尺寸、缩放和方向设置。
- 打印前检查缺失文件，可选择跳过缺失文件继续打印。
- 显示实时进度和运行日志，结束后输出成功/失败汇总。
- 打印过程中可停止后续任务；已提交的作业不受影响。
- 选中单个 `.doc`/`.docx` 文件后，可点击“转换预览”先查看 PDF 转换结果，再决定是否打印。
- `.doc`/`.docx` 转换时自动加载 macOS 系统中文字体，并映射宋体、仿宋、楷体、黑体等常见字体名，减少空白页和缺字问题。

## 项目结构

```text
BatchPrint/
  BatchPrintApp.swift
  Models/
    FileType.swift
    PrintFileItem.swift
    PrintJobStatus.swift
    PrintPreset.swift
  Services/
    ExternalDocumentPrinter.swift
    FileAvailabilityChecker.swift
    FolderScanner.swift
    OfficePDFConverter.swift
    PrintJobRunner.swift
    PrintPresetStore.swift
    PrinterService.swift
    WordDocumentPrinter.swift
  Views/
    ContentView.swift
    FileListView.swift
    PrintSettingsView.swift
    ProgressPanel.swift
Support/
  Info.plist
Package.swift
Makefile
```

## 在 Xcode 中打开

1. 使用 Xcode 15 或更新版本，在 macOS 14 或更高版本上打开 `BatchPrint.xcodeproj`。
2. 选择 `BatchPrint` scheme，然后运行。
3. 如提示代码签名，可将签名身份设置为 `Sign to Run Locally`，或使用 `com.local.BatchPrint` 作为 Bundle ID 的本地开发身份。

也可以直接打开根目录下的 `Package.swift`，以 Swift Package 方式运行 `BatchPrint` 可执行目标。

## 使用 SwiftPM 构建并打包 .app

在项目根目录执行：

```bash
swift build
```

生成可分发的 `.app`：

```bash
make app
open dist/BatchPrint.app
```

注意：当前工作环境只有 Command Line Tools，SwiftPM 编译已通过；完整的 Xcode 工程建议在安装了完整 Xcode 的机器上运行验证。

## 实现说明与已知限制

- PDF 和图片通过 `NSPrintOperation` 直接打印；PDF 支持 `1-3,5` 形式的自定义页面范围。
- `.doc`、`.docx` 文件会优先通过 LibreOffice/OpenOffice 的 headless 模式转换为 PDF，再使用 BatchPrint 的 PDF 打印流程，尽量保留原排版。
- 转换器会优先查找以下位置：
  - 环境变量 `BATCHPRINT_SOFFICE_PATH` 指定的 `soffice`
  - 常见 LibreOffice/OpenOffice 安装路径
  - 本机 Codex 运行时中的 LibreOffice
- 如果找不到 LibreOffice/OpenOffice，会退回使用 macOS `textutil` 转成 RTF 打印。
- 对于 Microsoft Word、Pages 和 TextEdit，仍会优先使用应用自身的 AppleScript 打印。
- 转换 PDF 时会自动生成临时 `fonts.conf`，加载 `/System/Library/Fonts`、`/System/Library/Fonts/Supplemental`、`/Library/Fonts` 和用户字体目录，并加入常见中文字体别名。
- macOS 系统通常没有“仿宋”“楷体”“方正小标宋简体”等字体，程序会将它们映射到系统已有的宋体或黑体，以保证内容完整，但字体样式可能不完全一致。若必须保持原字体，请先安装对应字体。
- 双面、色彩模式、缩放等参数会写入 `NSPrintInfo`，但实际效果取决于打印机驱动是否支持这些 key。
- AppleScript 自动打印首次运行时，macOS 可能要求授予自动化权限。
- 目前没有启用 App Sandbox，因此应用可以直接读取用户选择的文件夹。若要提交 App Store，需要补充沙盒配置与文件访问权限处理。

## 常见问题

### 为什么打印出来是空白页？

常见原因是 Word→PDF 转换时没有加载中文字体。BatchPrint 已通过临时 `fonts.conf` 强制加载 macOS 系统中文字体，并为宋体、仿宋、楷体、黑体等常见字体名设置替代规则。遇到问题时，先使用“转换预览”查看 PDF 是否正常。

### 为什么某些字体看起来不一样？

macOS 系统字体中可能没有原文档使用的“仿宋”“楷体”“方正小标宋简体”。BatchPrint 会用系统中文字体替代，因此内容会保留，但字体样式可能变化。安装对应字体后重新预览即可。

### 为什么 `.docx` 有时会退回 RTF 打印？

如果找不到 LibreOffice/OpenOffice，BatchPrint 会退回 `textutil` 的 RTF 打印。RTF 打印的排版保真度低于 PDF 转换，建议安装 LibreOffice 或设置 `BATCHPRINT_SOFFICE_PATH`。
