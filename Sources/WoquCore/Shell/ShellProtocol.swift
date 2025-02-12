import Foundation

public protocol ShellProtocol {
    /// Generate shell alias function
    func generateAliasFunction(name: String) -> String

    /// Get formatted command history
    func getCommandHistory(_ command: String?) -> [CommandHistory]

    /// Execute a shell command
    func executeCommand(_ command: String) -> CommandResult

    /// Parse a raw history line into command components
    func parseHistoryLine(_ line: String) -> (timestamp: Date, command: String)?
}

public struct CommandHistory {
    public let command: String
    public let result: CommandResult?
    public let timestamp: Date
}

public struct CommandResult {
    public let output: String
    public let errorOutput: String
    public let exitCode: Int32
}
