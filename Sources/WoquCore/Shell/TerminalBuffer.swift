import Foundation

/// 管理终端输出缓冲,实现滚动覆盖显示
public class TerminalBuffer: @unchecked Sendable {
    private var buffer: [String]
    private let maxLines: Int
    private var currentLineCount = 0

    public init(maxLines: Int = 10) {
        self.maxLines = maxLines
        self.buffer = []
    }

    /// 添加新内容并刷新显示
    private let lock = NSLock()
    private var cachedEscapeCodes = [Int: String]()

    public func append(_ content: String) {
        lock.lock()
        defer { lock.unlock() }

        let newLines = content.components(separatedBy: .newlines)

        // 缓冲区更新
        newLines.forEach { line in
            while buffer.count >= maxLines {
                buffer.removeFirst()
            }
            buffer.append(line)
        }

        // 计算需要处理的行数（取新旧行数的最大值）
        let linesToUpdate = max(newLines.count, currentLineCount)

        // 获取或生成ANSI转义码
        let escapeCode: String = {
            if let cached = cachedEscapeCodes[linesToUpdate] {
                return cached
            }
            let code = String(repeating: "\u{1B}[F\u{1B}[K", count: linesToUpdate)
            cachedEscapeCodes[linesToUpdate] = code
            return code
        }()

        // 执行终端更新
        print(escapeCode, terminator: "")
        print(newLines.joined(separator: "\n"), terminator: "")

        // 处理多余行清除
        if currentLineCount > newLines.count {
            let clearExtra = String(repeating: "\u{1B}[K\n", count: currentLineCount - newLines.count)
            print(clearExtra, terminator: "\u{1B}[\(newLines.count)A")
        }

        // 更新当前行计数（不超过最大行数）
        currentLineCount = min(buffer.count, maxLines)
    }

    /// 清除缓冲区
    public func clear() {
        // 清除所有已显示行
        if currentLineCount > 0 {
            let clearCommand = String(repeating: "\u{1B}[1A\u{1B}[K", count: currentLineCount)
            print(clearCommand)
        }
        buffer.removeAll()
        currentLineCount = 0
    }
}
