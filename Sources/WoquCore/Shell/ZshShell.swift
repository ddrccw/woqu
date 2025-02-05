import Foundation

public class ZshShell: ShellProtocol {
    public let historyFilePath: String
    private var commandOutputCache: [String: String] = [:]

    public init(historyFilePath: String = "\(NSHomeDirectory())/.zsh_history") {
        self.historyFilePath = historyFilePath
    }
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    public func parseHistoryLine(_ line: String) -> (timestamp: Date, command: String)? {
        // Zsh history format: ": <timestamp>:<seconds>;<command>"
        let components = line.components(separatedBy: ";")
        guard components.count == 2 else { return nil }

        let timestampPart = components[0]
        let command = components[1].trimmingCharacters(in: .whitespacesAndNewlines)

        // Extract timestamp from ": <timestamp>:<seconds>"
        let timestampComponents = timestampPart.components(separatedBy: ":")
        guard timestampComponents.count >= 3,
              let secondsSinceEpoch = Double(timestampComponents[1].trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }

        let timestamp = Date(timeIntervalSince1970: secondsSinceEpoch)
        return (timestamp, command)
    }

    public func getCommandHistory() -> [CommandHistory] {
        // Read history file directly for more accurate timestamps
        do {
            // Try UTF-8 first
            var historyContent: String
            if let utf8Content = try? String(contentsOfFile: historyFilePath, encoding: .utf8) {
                historyContent = utf8Content
            } else {
                // Fall back to latin1 if UTF-8 fails
                historyContent = try String(contentsOfFile: historyFilePath, encoding: .isoLatin1)
            }
            // Get all woqu commands from history in original order
            let allCommandHistory = historyContent.components(separatedBy: "\n")
            let allCommands: [(Date, String)] = allCommandHistory
                .compactMap { line in
                    guard let (timestamp, command) = parseHistoryLine(line),
                          command.contains("woqu") == false else {
                        // print("history cmd invalid line: \(line)")
                        return nil
                    }

                    // print("history cmd valid line: \(line)")
                    return (timestamp, command)
                }.suffix(10)

            // Take up to 10 most recent commands while maintaining original order
            let recentCommands = Array(allCommands)
            var historyEntries: [CommandHistory] = []

            // Execute only the last command
            if let (_, command) = recentCommands.last {
                historyEntries = recentCommands.map { (ts, cmd) in
                    if cmd == command {
                        let result = executeCommand(command)
                        return CommandHistory(
                            command: cmd,
                            output: result.errorOutput,
                            timestamp: ts
                        )
                    }
                    return CommandHistory(
                        command: cmd,
                        output: "",
                        timestamp: ts
                    )
                }
            }

            return historyEntries
        } catch {
            print("Error reading history file: \(error)")
            return []
        }
    }

    public func executeCommand(_ command: String) -> CommandResult {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        let semaphore = DispatchSemaphore(value: 0)

        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        var output = ""
        var errorOutput = ""
        var exitCode: Int32 = 0

        do {
            try process.run()

            // Process completed normally
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            output = String(data: outputData, encoding: .utf8) ?? ""
            errorOutput = String(data: errorData, encoding: .utf8) ?? ""
//            exitCode = process.terminationStatus

        } catch {
            print("Failed to execute Zsh command: \(error)")
            errorOutput = error.localizedDescription
        }

        return CommandResult(
            output: output,
            errorOutput: errorOutput,
            exitCode: errorOutput.isEmpty ? 0: -1
        )
    }
}
