import Foundation

public class BashShell: ShellProtocol {
    public let historyFilePath: String
    private var commandOutputCache: [String: String] = [:]

    public init(historyFilePath: String = "\(NSHomeDirectory())/.bash_history") {
        self.historyFilePath = historyFilePath
    }

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    public func parseHistoryLine(_ line: String) -> (timestamp: Date, command: String)? {
        // Bash history format: simple command per line
        let command = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !command.isEmpty else { return nil }

        // Bash doesn't store timestamps in history file by default
        // Use current time as fallback
        return (Date.now, command)
    }

    public func getCommandHistory(_ command: String?) -> [CommandHistory] {
        // Implementation similar to ZshShell but with Bash specific parsing
        do {
            let allCommands: [(Date, String)]
            if let command = command {
                allCommands = [
                    (Date.now, command)
                ]
            } else {
                let historyContent = try String(contentsOfFile: historyFilePath, encoding: .utf8)
                let allCommandHistory = historyContent.components(separatedBy: "\n")
                allCommands = allCommandHistory
                    .compactMap { line in
                        guard let (timestamp, command) = parseHistoryLine(line),
                              command.contains("woqu") == false else {
                            return nil
                        }
                        return (timestamp, command)
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
        } catch {
            Logger.error("Error reading history file: \(error)")
            return []
        }
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