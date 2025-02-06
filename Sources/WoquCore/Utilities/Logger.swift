import Foundation
import Rainbow

@globalActor
public actor LoggerActor { // 自定义的 actor
    static public let shared = LoggerActor()
}

@LoggerActor
public class Logger {
    public enum Level: String, CaseIterable {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"

        var color: Color {
            switch self {
            case .debug: return .cyan
            case .info: return .green
            case .warning: return .yellow
            case .error: return .red
            }
        }

        var icon: String {
            switch self {
            case .debug: return "🛠"
            case .info: return "✅"
            case .warning: return "⚠️"
            case .error: return "❌"
            }
        }
    }

    public static var logLevel: Level = .info
    public static var showColors = true

    public static func debug(_ message: String, tag: String = "General", file: String = #file, line: Int = #line) {
        log(level: .debug, message: message, tag: tag, file: file, line: line)
    }

    public static func info(_ message: String, tag: String = "General", file: String = #file, line: Int = #line) {
        log(level: .info, message: message, tag: tag, file: file, line: line)
    }

    public static func warning(_ message: String, tag: String = "General", file: String = #file, line: Int = #line) {
        log(level: .warning, message: message, tag: tag, file: file, line: line)
    }

    public static func error(_ message: String, tag: String = "General", file: String = #file, line: Int = #line) {
        log(level: .error, message: message, tag: tag, file: file, line: line)
    }

    private static func log(level: Level, message: String, tag: String, file: String, line: Int) {
        guard level.rawValue >= logLevel.rawValue else { return }

        let timestamp = Date().ISO8601Format()
        let fileName = URL(fileURLWithPath: file).lastPathComponent

        var logComponents = [
            "\(timestamp)",
            "[\(level.icon) \(level.rawValue)]",
            "[\(tag)]",
            "\(fileName):\(line)",
            "- \(message)"
        ]

        if showColors {
            logComponents[1] = logComponents[1].applyingColor(level.color)
            logComponents[3] = message.applyingColor(level.color)
        }

        print(logComponents.joined(separator: " "))
    }
}
