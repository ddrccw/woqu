import Foundation
import Rainbow

/// Status for terminal state
public enum TerminalState {
    case waiting
    case success
    case error
    case info
    case subInfo
    case prompt  // special sub info
}

public struct TerminalEvent {
    let message: String
    let state: TerminalState
    let timestamp: Date

    init(message: String, state: TerminalState) {
        self.message = message
        self.state = state
        self.timestamp = Date()
    }
}

/// Default terminal progress display implementation
public actor TerminalDisplay {
    static let shared = TerminalDisplay()
    private let spinnerFrames = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
    private var currentFrame = 0

    private var currentTask: Task<Void, Never>?
    private var isWaiting = false
    private var shouldClearLine = false // Default to clearLine
    private var subInfoCount = 0

    public init() {}

    private func formatEvent(_ event: TerminalEvent) -> String {
        switch event.state {
        case .success:
            return "✅ \(event.message)".cyan
        case .error:
            return "❎ \(event.message)".red
        case .info:
            return "ℹ️ \(event.message)".green
        case .subInfo:
            return "\(event.message)".white
        case .prompt:
            return "❓ \(event.message)".lightYellow
        case .waiting:
            return event.message.yellow
        }
    }

    public func display(_ event: TerminalEvent, shouldClearLine: Bool = true) {
        clearLine(shouldClearLine)
        let formattedMessage = formatEvent(event)
        print(formattedMessage)
    }

    private func showWaitingAnimation(message: String) {
        guard !isWaiting else { return }
        isWaiting = true

        currentTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.updateWaitingFrame(message: message)
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            }
        }
    }

    private func stopWaitingAnimation() {
        currentTask?.cancel()
        currentTask = nil
        isWaiting = false
        clearLine()
    }

    private func updateWaitingFrame(message: String) {
        clearLine()
        let frame = spinnerFrames[currentFrame]
        print("\(frame) \(message)".yellow, terminator: "")
        fflush(stdout)
        currentFrame = (currentFrame + 1) % spinnerFrames.count
    }

    public func info(_ message: String) {
        display(TerminalEvent(message: message, state: .info),
                shouldClearLine: shouldClearLine)
    }

    public func subInfo(_ message: String, shouldClearLine: Bool = false) {
        subInfoCount += 1
        display(TerminalEvent(message: message, state: .subInfo),
                shouldClearLine: shouldClearLine)
    }

    public func clearSubInfo(count: Int? = nil) {
        guard subInfoCount > 0 else { return }
        if let count = count {
            if count < subInfoCount {
                subInfoCount -= count
            }
            clearLines(count)
            return
        }
        clearLines(subInfoCount)
        subInfoCount = 0
    }

    public func success(_ message: String) {
        display(TerminalEvent(message: message, state: .success),
                shouldClearLine: shouldClearLine)
    }

    public func error(_ message: String) {
        display(TerminalEvent(message: message, state: .error),
                shouldClearLine: shouldClearLine)
    }

    public func startWaiting(_ message: String) {
        showWaitingAnimation(message: message)
    }

    public func stopWaiting() {
        stopWaitingAnimation()
    }

    public func confirm(_ message: String) async -> Bool {
        subInfoCount += 1
        display(TerminalEvent(message: "\(message) (y/n)", state: .prompt),
                shouldClearLine: false)
        guard let input = readLine()?.lowercased() else { return false }
        return input == "y" || input == "yes"
    }

    private func clearLine(_ shouldClearLine: Bool = true) {
        guard shouldClearLine else { return }
        clearLines(1)
    }

    private enum ANSIControl: String {
        case clearLine = "\u{001B}[2K"     // clear line
        case cursorUp = "\u{001B}[1A"      // move cursor up
        case cursorToStart = "\r"          // move cursor to start of line
    }

    /// clear the last n lines
    private func clearLines(_ count: Int) {
        for _ in 0..<count {
            // clear current line
            print(ANSIControl.clearLine.rawValue + ANSIControl.cursorToStart.rawValue, terminator: "")
            if count > 1 {
                // move cursor up (if more than 1 line)
                print(ANSIControl.cursorUp.rawValue, terminator: "")
            }
        }
        fflush(stdout)
    }
}

