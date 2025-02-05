import Foundation

public struct AIPromptTemplate {
    static let commandCorrectionPrompt = """
    Analyze the following incorrect command and its context to suggest the most likely correct command:

    Context:
    - Current directory: %@
    - Command history: %@
    - System environment: %@
    - Error message: %@

    Incorrect command: %@

    Provide a JSON response with the following structure:
    {
        "explanation": "Brief explanation of the issue and correction",
        "commands": [
            {
                "command": "exact command to execute",
                "description": "what this command does"
            }
        ]
    }

    The commands should be executable in a Unix-like shell environment.
    If multiple steps are needed, provide them in order.
    """

    static public func generatePrompt(currentDir: String,
                             history: [String],
                             environment: [String: String],
                             error: String,
                             command: String) -> String {
        let historyStr = history.joined(separator: "\n")

        /*
        // Filter out sensitive environment variables
        let filteredEnv = environment.filter {
            let lowerKey = $0.key.lowercased()
            return !lowerKey.contains("token") &&
                   !lowerKey.contains("key") &&
                   !lowerKey.contains("secret")
        }
        let envStr = filteredEnv.map { "\($0.key)=\($0.value)" }.joined(separator: "\n")
        */

        return String(format: commandCorrectionPrompt,
                     currentDir,
                     historyStr,
                     "", //envStr, // TODO: env
                     error,
                     command)
    }
}
