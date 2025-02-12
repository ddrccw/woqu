import Foundation

public class FishShell: ShellProtocol {
    public let historyFilePath: String
    private var commandOutputCache: [String: String] = [:]

    public init(historyFilePath: String = "\(NSHomeDirectory())/.local/share/fish/fish_history") {
        self.historyFilePath = historyFilePath
    }

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    public func generateAliasFunction(name: String) -> String {
        return ""
    }

    public func parseHistoryLine(_ line: String) -> (timestamp: Date, command: String)? {
        // Fish history format: JSON with timestamp and command
        guard let data = line.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let command = json["cmd"] as? String,
              let timestamp = json["when"] as? Double else {
            return nil
        }

        return (Date(timeIntervalSince1970: timestamp), command)
    }

    public func getCommandHistory(_ command: String?) -> [CommandHistory] {
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

        process.executableURL = URL(fileURLWithPath: "/usr/local/bin/fish")
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
            Logger.error("Failed to execute Fish command: \(error)")
            errorOutput = error.localizedDescription
            exitCode = process.terminationStatus
        }

        return CommandResult(output: output,
                             errorOutput: errorOutput,
                             exitCode: exitCode)
    }
}
