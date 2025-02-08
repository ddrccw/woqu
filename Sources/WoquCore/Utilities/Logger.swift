import Foundation
import Rainbow

public class Logger {
    public enum Level: String, CaseIterable, Sendable {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
        case none

        // 定义优先级
        var priority: Int {
            switch self {
            case .debug: return 0
            case .info: return 1
            case .warning: return 2
            case .error: return 3
            case .none: return 4
            }
        }

        var color: Color {
            switch self {
            case .debug: return .cyan
            case .info: return .green
            case .warning: return .yellow
            case .error: return .red
            case .none: return .white
            }
        }

        var icon: String {
            switch self {
            case .debug: return "🛠"
            case .info: return "✅"
            case .warning: return "⚠️"
            case .error: return "❌"
            case .none: return ""
            }
        }
    }

    @TaskLocal public static var logLevel: Level = .none
    @TaskLocal public static var showColors = true
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

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
        guard level.priority >= logLevel.priority else { return }

        let timestamp = dateFormatter.string(from: Date())
        let fileName = URL(fileURLWithPath: file).lastPathComponent

        let logComponents = [
            "\(timestamp)",
            "[\(level.icon) \(level.rawValue)]",
            "[\(tag)]",
            "\(fileName):\(line)",
            "- \(message)"
        ]

        var finalMessage = logComponents.joined(separator: " ")
        if showColors {
            finalMessage = finalMessage.applyingColor(level.color)
        }

        print(finalMessage)
    }
}
