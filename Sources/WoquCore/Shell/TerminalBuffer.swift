import Foundation

/// Manages terminal output buffer, implements scrolling and overwriting display.
public class TerminalBuffer: @unchecked Sendable {
    private var buffer: [String]
    private let maxLines: Int
    private var currentLineCount = 0

    public init(maxLines: Int = 10) {
        self.maxLines = maxLines
        self.buffer = []
    }

    /// Adds new content and refreshes the display.
    private let lock = NSLock()
    private var cachedEscapeCodes = [Int: String]()

    public func append(_ content: String) {
        lock.lock()
        defer { lock.unlock() }

        let newLines = content.components(separatedBy: .newlines)

        // Update the buffer
        newLines.forEach { line in
            while buffer.count >= maxLines {
                buffer.removeFirst()
            }
            buffer.append(line)
        }

        // Calculate the number of lines to update (take the maximum of new and old line counts)
        let linesToUpdate = max(newLines.count, currentLineCount)

        // Get or generate ANSI escape codes
        let escapeCode: String = {
            if let cached = cachedEscapeCodes[linesToUpdate] {
                return cached
            }
            let code = String(repeating: "\u{1B}[F\u{1B}[K", count: linesToUpdate)
            cachedEscapeCodes[linesToUpdate] = code
            return code
        }()

        // Execute terminal update
        print(escapeCode, terminator: "")
        print(newLines.joined(separator: "\n"), terminator: "")

        // Handle clearing extra lines
        if currentLineCount > newLines.count {
            let clearExtra = String(repeating: "\u{1B}[K\n", count: currentLineCount - newLines.count)
            print(clearExtra, terminator: "\u{1B}[\(newLines.count)A")
        }

        // Update the current line count (not exceeding the maximum number of lines)
        currentLineCount = min(buffer.count, maxLines)
    }

    /// Clears the buffer.
    public func clear() {
        // Clear all displayed lines
        if currentLineCount > 0 {
            let clearCommand = String(repeating: "\u{1B}[1A\u{1B}[K", count: currentLineCount)
            print(clearCommand)
        }
        buffer.removeAll()
        currentLineCount = 0
    }
}
