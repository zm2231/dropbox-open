import Foundation

public enum FinderExtensionStatus: Equatable {
    case enabled
    case disabled
    case notFound
    case unknown(String)

    public var isUsable: Bool {
        self == .enabled
    }

    public var menuLabel: String {
        switch self {
        case .enabled:
            return "Finder Extension: Enabled"
        case .disabled:
            return "Finder Extension: Disabled"
        case .notFound:
            return "Finder Extension: Not Registered"
        case .unknown:
            return "Finder Extension: Needs Attention"
        }
    }

    public static func parse(pluginkitOutput output: String) -> FinderExtensionStatus {
        let lines = output
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        if lines.contains(where: { $0.contains("(no matches)") }) {
            return .notFound
        }
        if lines.contains(where: { $0.hasPrefix("+") }) {
            return .enabled
        }
        if lines.contains(where: { $0.hasPrefix("-") }) {
            return .disabled
        }

        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? .notFound : .unknown(trimmed)
    }
}

public enum FinderExtensionDoctor {
    public static let extensionBundleID = "com.merchantry.dropbox-open.findersync"

    public static func status() -> FinderExtensionStatus {
        let result = runPlugInKit(arguments: ["-m", "-v", "-i", extensionBundleID])
        return FinderExtensionStatus.parse(pluginkitOutput: result.output)
    }

    public static func enable() -> FinderExtensionStatus {
        _ = runPlugInKit(arguments: ["-e", "use", "-i", extensionBundleID])
        return status()
    }

    private static func runPlugInKit(arguments: [String]) -> (output: String, status: Int32) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pluginkit")
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return (error.localizedDescription, 1)
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return (String(data: data, encoding: .utf8) ?? "", process.terminationStatus)
    }
}
