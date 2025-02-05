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
        // Bash history format: "#<timestamp>\n<command>"
        let components = line.components(separatedBy: "\n")
        guard components.count == 2,
              components[0].hasPrefix("#"),
              let timestamp = Double(components[0].dropFirst()) else {
            return nil
        }

        let command = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
        return (Date(timeIntervalSince1970: timestamp), command)
    }

    public func getCommandHistory() -> [CommandHistory] {
        // Read history file directly for more accurate timestamps
        do {
            let historyContent = try String(contentsOfFile: historyFilePath)
            return historyContent.components(separatedBy: "\n")
                .compactMap { line in
                    guard let (timestamp, command) = parseHistoryLine(line) else {
                        return nil
                    }
                    // Check cache first
                    if let cachedOutput = commandOutputCache[command] {
                        return CommandHistory(
                            command: command,
                            output: cachedOutput,
                            timestamp: timestamp
                        )
                    }

                    // Execute command and cache result
                    let result = executeCommand(command)
                    commandOutputCache[command] = result.output
                    return CommandHistory(
                        command: command,
                        output: result.output,
                        timestamp: timestamp
                    )
                }
        } catch {
            print("Error reading history file: \(error)")
            return []
        }
    }

    public func executeCommand(_ command: String) -> CommandResult {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

            let output = String(data: outputData, encoding: .utf8) ?? ""
            let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

            return CommandResult(
                output: output,
                errorOutput: errorOutput,
                exitCode: process.terminationStatus
            )
        } catch {
            print("Failed to execute Bash command: \(error)")
            return CommandResult(
                output: "",
                errorOutput: error.localizedDescription,
                exitCode: -1
            )
        }
    }
}
