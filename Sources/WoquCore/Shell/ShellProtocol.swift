import Foundation

public protocol ShellProtocol {
    /// Path to the shell's history file
    var historyFilePath: String { get }

    /// Get formatted command history
    func getCommandHistory() -> [CommandHistory]

    /// Execute a shell command
    func executeCommand(_ command: String) -> CommandResult

    /// Parse a raw history line into command components
    func parseHistoryLine(_ line: String) -> (timestamp: Date, command: String)?
}

public struct CommandHistory {
    public let command: String
    public let output: String
    public let timestamp: Date
}

public struct CommandResult {
    public let output: String
    public let errorOutput: String
    public let exitCode: Int32
}

extension ShellProtocol {
    /// Default implementation to get history file path from environment
    public var historyFilePath: String {
        return ProcessInfo.processInfo.environment["HISTFILE"]
            ?? FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".zsh_history").path
    }
}
