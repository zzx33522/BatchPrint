import Foundation

enum OfficePDFConverter {
    static func convertToPDF(sourceURL: URL) async throws -> URL {
        try await Task.detached(priority: .userInitiated) {
            guard let sofficeURL = libreOfficeExecutable() else {
                throw PrintRunnerError.officeConversionFailed(
                    "未找到 LibreOffice/OpenOffice。可安装 LibreOffice，或设置 BATCHPRINT_SOFFICE_PATH。"
                )
            }

            let outputDirectory = FileManager.default.temporaryDirectory
                .appendingPathComponent("BatchPrint-\(UUID().uuidString)", isDirectory: true)
            let profileDirectory = outputDirectory.appendingPathComponent("profile", isDirectory: true)
            let fontCacheDirectory = outputDirectory.appendingPathComponent("fontcache", isDirectory: true)
            try FileManager.default.createDirectory(at: profileDirectory, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: fontCacheDirectory, withIntermediateDirectories: true)

            let fontConfigurationURL = outputDirectory.appendingPathComponent("fonts.conf")
            let homeFontDirectory = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Fonts", isDirectory: true)
            let fontConfiguration = """
            <?xml version="1.0"?>
            <!DOCTYPE fontconfig SYSTEM "fonts.dtd">
            <fontconfig>
                <dir>/System/Library/Fonts</dir>
                <dir>/System/Library/Fonts/Supplemental</dir>
                <dir>/Library/Fonts</dir>
                <dir>\(homeFontDirectory.path)</dir>
                <cachedir>\(fontCacheDirectory.path)</cachedir>
                <match target="pattern"><test name="family"><string>宋体</string></test><edit name="family" mode="prepend" binding="strong"><string>宋体-简</string></edit></match>
                <match target="pattern"><test name="family"><string>SimSun</string></test><edit name="family" mode="prepend" binding="strong"><string>宋体-简</string></edit></match>
                <match target="pattern"><test name="family"><string>NSimSun</string></test><edit name="family" mode="prepend" binding="strong"><string>宋体-简</string></edit></match>
                <match target="pattern"><test name="family"><string>仿宋</string></test><edit name="family" mode="prepend" binding="strong"><string>宋体-简</string></edit></match>
                <match target="pattern"><test name="family"><string>仿宋_GB2312</string></test><edit name="family" mode="prepend" binding="strong"><string>宋体-简</string></edit></match>
                <match target="pattern"><test name="family"><string>FangSong</string></test><edit name="family" mode="prepend" binding="strong"><string>宋体-简</string></edit></match>
                <match target="pattern"><test name="family"><string>FangSong_GB2312</string></test><edit name="family" mode="prepend" binding="strong"><string>宋体-简</string></edit></match>
                <match target="pattern"><test name="family"><string>楷体</string></test><edit name="family" mode="prepend" binding="strong"><string>宋体-简</string></edit></match>
                <match target="pattern"><test name="family"><string>楷体_GB2312</string></test><edit name="family" mode="prepend" binding="strong"><string>宋体-简</string></edit></match>
                <match target="pattern"><test name="family"><string>KaiTi</string></test><edit name="family" mode="prepend" binding="strong"><string>宋体-简</string></edit></match>
                <match target="pattern"><test name="family"><string>KaiTi_GB2312</string></test><edit name="family" mode="prepend" binding="strong"><string>宋体-简</string></edit></match>
                <match target="pattern"><test name="family"><string>方正小标宋简体</string></test><edit name="family" mode="prepend" binding="strong"><string>宋体-简</string></edit></match>
                <match target="pattern"><test name="family"><string>黑体</string></test><edit name="family" mode="prepend" binding="strong"><string>黑体-简</string></edit></match>
                <match target="pattern"><test name="family"><string>SimHei</string></test><edit name="family" mode="prepend" binding="strong"><string>黑体-简</string></edit></match>
                <match target="pattern"><test name="family"><string>MS Gothic</string></test><edit name="family" mode="prepend" binding="strong"><string>冬青黑体简体中文</string></edit></match>
            </fontconfig>
            """
            try fontConfiguration.write(
                to: fontConfigurationURL,
                atomically: true,
                encoding: .utf8
            )

            let process = Process()
            process.executableURL = sofficeURL
            process.arguments = [
                "-env:UserInstallation=file://\(profileDirectory.path)",
                "--headless",
                "--convert-to",
                "pdf",
                "--outdir",
                outputDirectory.path,
                sourceURL.path
            ]
            var environment = ProcessInfo.processInfo.environment
            environment["FONTCONFIG_FILE"] = fontConfigurationURL.path
            environment["XDG_CACHE_HOME"] = outputDirectory.path
            process.environment = environment

            let standardOutput = Pipe()
            let standardError = Pipe()
            process.standardOutput = standardOutput
            process.standardError = standardError

            try process.run()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else {
                let errorData = standardError.fileHandleForReading.readDataToEndOfFile()
                let message = String(data: errorData, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? "未知错误"
                throw PrintRunnerError.officeConversionFailed(message)
            }

            let expectedName = sourceURL.deletingPathExtension().lastPathComponent + ".pdf"
            let expectedURL = outputDirectory.appendingPathComponent(expectedName)
            if FileManager.default.fileExists(atPath: expectedURL.path) {
                return expectedURL
            }

            let pdfFiles = try FileManager.default.contentsOfDirectory(
                at: outputDirectory,
                includingPropertiesForKeys: nil
            ).filter { $0.pathExtension.lowercased() == "pdf" }

            guard let firstPDF = pdfFiles.first else {
                throw PrintRunnerError.officeConversionFailed("转换完成，但未找到 PDF 输出文件。")
            }

            return firstPDF
        }.value
    }

    private static func libreOfficeExecutable() -> URL? {
        var candidates: [URL] = []

        if let configured = ProcessInfo.processInfo.environment["BATCHPRINT_SOFFICE_PATH"],
           !configured.isEmpty {
            candidates.append(URL(fileURLWithPath: configured))
        }

        let home = FileManager.default.homeDirectoryForCurrentUser
        candidates.append(
            home.appendingPathComponent(
                ".cache/codex-runtimes/codex-primary-runtime/dependencies/native/libreoffice-headless/libreoffice/LibreOfficeDev.app/Contents/MacOS/soffice"
            )
        )
        candidates.append(URL(fileURLWithPath: "/Applications/LibreOffice.app/Contents/MacOS/soffice"))
        candidates.append(URL(fileURLWithPath: "/Applications/OpenOffice.app/Contents/MacOS/soffice"))
        candidates.append(URL(fileURLWithPath: "/opt/homebrew/bin/soffice"))
        candidates.append(URL(fileURLWithPath: "/usr/local/bin/soffice"))
        candidates.append(URL(fileURLWithPath: "/usr/bin/soffice"))

        return candidates.first {
            FileManager.default.isExecutableFile(atPath: $0.path)
        }
    }
}
