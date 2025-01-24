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

    public func getRawHistoryLines(limit: Int = 10) -> [String] {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-i", "-c", "history -r; history \(limit)"]
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else {
                return []
            }

            // Parse history output format: " 1234  command"
            return output.components(separatedBy: "\n")
                .filter { !$0.isEmpty }
                .map { line in
                    // Remove leading number and space
                    let components = line.components(separatedBy: .whitespaces)
                    return components.dropFirst().joined(separator: " ")
                }
        } catch {
            print("Error getting Bash raw history: \(error)")
            return []
        }
    }

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
            // Fallback to raw history lines
            return getRawHistoryLines().map {
                // Check cache first
                if let cachedOutput = commandOutputCache[$0] {
                    return CommandHistory(
                        command: $0,
                        output: cachedOutput,
                        timestamp: Date()
                    )
                }

                // Execute command and cache result
                let result = executeCommand($0)
                commandOutputCache[$0] = result.output
                return CommandHistory(
                    command: $0,
                    output: result.output,
                    timestamp: Date()
                )
            }
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
