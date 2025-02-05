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

    public func getCommandHistory(_ command: String?) -> [CommandHistory] {
        // Read history file directly for more accurate timestamps
        do {
            let allCommands: [(Date, String)]
            if let command = command {
                allCommands = [
                    (Date.now, command)
                ]
            } else {
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
                allCommands = allCommandHistory
                    .compactMap { line in
                        guard let (timestamp, command) = parseHistoryLine(line),
                            command.contains("woqu") == false else {
                            // print("history cmd invalid line: \(line)")
                            return nil
                        }

                        // print("history cmd valid line: \(line)")
                        return (timestamp, command)
                    }.suffix(10)
            }
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
            print("Error reading history file: \(error)")
            return []
        }
    }

    public func executeCommand(_ command: String) -> CommandResult {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        // 使用原子队列保护共享变量
        let queue = DispatchQueue(label: "com.woqu.syncQueue")
        var output = ""
        var errorOutput = ""
        var exitCode: Int32 = 0
        let timeout: TimeInterval = 3
        var timedOut = false

        do {
            try process.run()

            // 使用 weak 避免循环引用
            let timeoutWorkItem = DispatchWorkItem { [weak process, weak queue] in
                queue?.sync {
                    if let process = process, process.isRunning {
                        timedOut = true
                        kill(process.processIdentifier, SIGTERM)
                    }
                }
            }

            // 在全局队列安排超时
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: timeoutWorkItem)

            process.waitUntilExit()
            timeoutWorkItem.cancel() // 如果进程提前完成，取消超时任务

            queue.sync {
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
            }
        } catch {
            print("Failed to execute Zsh command: \(error)")
            errorOutput = error.localizedDescription
            exitCode = process.terminationStatus
        }

        return CommandResult(output: output,
                             errorOutput: errorOutput,
                             exitCode: exitCode)
    }
}
