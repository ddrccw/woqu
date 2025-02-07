//
//  File.swift
//  woqu
//
//  Created by alibaba on 2025/2/7.
//

import Foundation

class SuggestService {
    private let apiClient: APIClient
    private let maxRetries = 3
    private let retryDelay: UInt64 = 1_000_000_000 // 1 second in nanoseconds

    init(provider: Provider.Name? = nil) throws {
        // load config
        let config = try ConfigManager.shared.loadConfig()

        // get provider
        let providerConfig: Provider
        if let provider = provider, let config = config.providers[provider] {
            providerConfig = config
        } else {
            Logger.warning("Provider \(String(describing: provider)) not found in config, using default provider \(config.defaultProvider)")
            guard let defaultConfig = config.providers[config.defaultProvider] else {
                throw WoquError.initError(.invalidProvider(config.defaultProvider))
            }
            providerConfig = defaultConfig
        }

        // get api client
        self.apiClient = APIClient(
            provider: providerConfig
        )
    }

    func run(command: String?, dryRun: Bool) async throws {
        // get command history
        let history = getCommandHistory(command)

        let suggestion: CommandSuggestion = try await getCommandSuggestionWithRetry(history: history)

        // display reason
        if let think = suggestion.think {
            Logger.info("""
            Reason:
            \(think)
            """)
        }

        // display suggestion
        Logger.info("""
        Explanation:
        \(suggestion.explanation)
        """)

        // ask user to execute commands
        for (index, command) in suggestion.commands.enumerated() {
            Logger.info("""
            Command \(index + 1):
            \(command.command)
            Description: \(command.description)
            """)

            if !dryRun {
                Logger.info("Execute command '\(command.command)'? (y/n)")
                if let input = readLine(), input.lowercased() == "y" {
                    let result = executeCommand(command.command)
                    Logger.info(result)
                } else {
                    Logger.info("Command not executed")
                }
            }
        }
    }

    func getCommandSuggestionWithRetry(history: [CommandHistory]) async throws -> CommandSuggestion {
        let currentDir = FileManager.default.currentDirectoryPath

        // Get environment variables
        let environment = ProcessInfo.processInfo.environment
        Logger.debug("Environment: \(environment.wq_toDebugJSONString() ?? "")")

        // Get command history with error context
        let historyWithErrors = history

        // Skip API call if no error output exists
        guard let lastError = historyWithErrors.last,
              let result = lastError.result else {
            throw WoquError.commandError(.execNoError())
        }

        // Skip API call if execution timeout
        guard result.exitCode != SIGTERM else {
            throw WoquError.commandError(.timeout(command: lastError.command))
        }

        guard result.exitCode != 0 else {
            throw WoquError.commandError(.execNoError(command: lastError.command))
        }

        // Create prompt using template
        let prompt = AIPromptTemplate.generatePrompt(
            currentDir: currentDir,
            history: historyWithErrors.map { $0.command },
            environment: environment,
            error: result.errorOutput,
            command: lastError.command
        )

        for attempt in 1...maxRetries {
            do {
                // Get suggestion using the formatted prompt
                let suggestion = try await apiClient.getCompletion(prompt: prompt)

                // Validate commands
                for command in suggestion.commands {
                    guard validateCommand(command.command) else {
                        throw WoquError.commandError(.invalidCommand(command.command))
                    }
                }
                return suggestion
            } catch {
                Logger.debug("getCommandSuggestionWithRetry: \(error)")

                if attempt < maxRetries {
                    Logger.info("Retrying in 1 second... (attempt \(attempt)/\(maxRetries))")
                    try await Task.sleep(nanoseconds: retryDelay)
                }
            }
        }

        throw WoquError.commandError(.suggestFailed(lastError.command))
    }

    private func validateCommand(_ command: String) -> Bool {
        // Basic validation rules
        guard !command.isEmpty else { return false }
        guard !command.contains("rm -rf /") else { return false } // Prevent dangerous commands
        return true
    }

    private func getCommandHistory(_ command: String?) -> [CommandHistory] {
        let shell = ShellFactory.createShell()
        return shell.getCommandHistory(command)
    }

    private func executeCommand(_ command: String) -> String {
        let shell = ShellFactory.createShell()
        let result = shell.executeCommand(command)
        if result.exitCode == 0 {
            return result.output
        } else {
            return "Error executing command: \(result.output), error: \(result.errorOutput), exit code: \(result.exitCode)"
        }
    }

}
