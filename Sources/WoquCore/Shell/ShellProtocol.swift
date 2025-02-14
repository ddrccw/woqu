import Foundation

public protocol ShellProtocol {
    /// Check if shell is configured, e.g. bash requires injected alias function
    func isConfigured() -> Bool

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

public class Shell: ShellProtocol {
    public func isConfigured() -> Bool {
        return true
    }
    
    public func generateAliasFunction(name: String) -> String {
        return ""
    }
    
    public func getCommandHistory(_ command: String?) -> [CommandHistory] {
        fatalError("getCommandHistory not implemented")
    }
    
    public func executeCommand(_ command: String) -> CommandResult {
        fatalError("executeCommand not implemented")
    }
    
    public func parseHistoryLine(_ line: String) -> (timestamp: Date, command: String)? {
        fatalError("parseHistoryLine not implemented")
    }

    public let type : ShellType
    required init(type : ShellType) throws {
        self.type = type
    }

    
}
