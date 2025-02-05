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

    public func parseHistoryLine(_ line: String) -> (timestamp: Date, command: String)? {
        // Fish history format: "- cmd: command\n   when: timestamp"
        let components = line.components(separatedBy: "\n")
        guard components.count == 2,
              components[0].hasPrefix("- cmd: "),
              components[1].hasPrefix("   when: "),
              let timestamp = Double(components[1].replacingOccurrences(of: "   when: ", with: "")) else {
            return nil
        }

        let command = components[0].replacingOccurrences(of: "- cmd: ", with: "")
        return (Date(timeIntervalSince1970: timestamp), command)
    }

    public func getCommandHistory() -> [CommandHistory] {
        // Read history file directly for more accurate timestamps
        do {
            let historyContent = try String(contentsOfFile: historyFilePath)
            return historyContent.components(separatedBy: "\n\n")
                .compactMap { block in
                    let lines = block.components(separatedBy: "\n")
                    guard lines.count >= 2,
                          let (timestamp, command) = parseHistoryLine(block) else {
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

        process.executableURL = URL(fileURLWithPath: "/usr/local/bin/fish")
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
            print("Failed to execute Fish command: \(error)")
            return CommandResult(
                output: "",
                errorOutput: error.localizedDescription,
                exitCode: -1
            )
        }
    }
}
