import Foundation

public class BashShell: ShellProtocol {
    private var commandOutputCache: [String: String] = [:]

    public init() {}

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    public func generateAliasFunction(name: String) -> String {
       return """
       \(name)() {
           export WQ_HISTORY="$(history)"
           command woqu "$@"
           unset WQ_HISTORY
       }
       """
    }

    public func parseHistoryLine(_ line: String) -> (timestamp: Date, command: String)? {
        // Bash history format: [number] command or command
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLine.isEmpty else { return nil }

        // Split into components
        let components = trimmedLine.components(separatedBy: .whitespaces)

        // Extract command
        let command: String
        if components.count > 1 && components[0].rangeOfCharacter(from: .decimalDigits) != nil {
            // Format with number: [number] command
            command = components.dropFirst().joined(separator: " ")
        } else {
            // Simple command format
            command = trimmedLine
        }

        return (Date.now, command)
    }

    public func getCommandHistory(_ command: String?) -> [CommandHistory] {
        let allCommands: [(Date, String)]
        if let command = command {
            allCommands = [
                (Date.now, command)
            ]
        } else {
            let history = ProcessInfo.processInfo.environment["WQ_HISTORY"] ?? ""
            let allCommandHistory = history.components(separatedBy: "\n")
            allCommands = allCommandHistory
                .compactMap { line in
                    guard let (date, command) = parseHistoryLine(line) else {
                        return nil
                    }
                    // Filter out woqu commands with or without paths
                    let woquPattern: String = #"(^|\s)(/.*/)?woqu(\s|$)"#
                    if command.range(of: woquPattern, options: .regularExpression) != nil {
                        return nil
                    }
                    return (date, command)
                }.suffix(10)
        }

        let recentCommands = Array(allCommands)
        var historyEntries: [CommandHistory] = []

        if let (_, command) = recentCommands.last {
            historyEntries = recentCommands.map { (ts, cmd) in
                if cmd == command {
                    let result = executeCommand(command)
                    return CommandHistory(
                        command: cmd,
                        result: result,
                        timestamp: ts
                    )
                }
                return CommandHistory(
                    command: cmd,
                    result: nil,
                    timestamp: ts
                )
            }
        }

        return historyEntries
    }

    public func executeCommand(_ command: String) -> CommandResult {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]
        process.environment = ProcessInfo.processInfo.environment
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        var output = ""
        var errorOutput = ""
        var exitCode: Int32 = 0
        let timeout: TimeInterval = 30
        var timedOut = false

        do {
            try process.run()

            let timeoutTask = Task {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                if process.isRunning {
                    timedOut = true
                    kill(process.processIdentifier, SIGTERM)
                }
            }

            process.waitUntilExit()
            timeoutTask.cancel()

            if timedOut {
                errorOutput = "Command timed out after \(timeout) seconds"
                exitCode = process.terminationStatus
            } else {
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                output = String(data: outputData, encoding: .utf8) ?? ""
                errorOutput = String(data: errorData, encoding: .utf8) ?? ""
                exitCode = process.terminationStatus
            }
        } catch {
            Logger.error("Failed to execute Bash command: \(error)")
            errorOutput = error.localizedDescription
            exitCode = process.terminationStatus
        }

        return CommandResult(output: output,
                             errorOutput: errorOutput,
                             exitCode: exitCode)
    }
}
