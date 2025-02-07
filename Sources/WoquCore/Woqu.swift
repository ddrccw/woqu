import Foundation
import ArgumentParser
import Darwin

extension Provider.Name: ExpressibleByArgument {
    public init?(argument: String) {
        if let value = Provider.Name(rawValue: argument.lowercased()) {
            self = value
        } else {
            return nil
        }
    }
}

@MainActor
final public class Woqu {
    private let configManager = ConfigManager.shared
    private var apiClient: APIClient?
    private let maxRetries = 3
    private let retryDelay: UInt64 = 1_000_000_000 // 1 second in nanoseconds

    public init() {
    }

    public func run(_ command: String?,
                    provider: Provider.Name? = nil,
                    dryRun: Bool) async {
        do {
            // load config
            let config = try configManager.loadConfig()

            // get provider
            let providerConfig: Provider
            if let provider = provider, let config = config.providers[provider] {
                providerConfig = config
            } else {
                print("Warning: Provider \(String(describing: provider)) not found in config, using default provider \(config.defaultProvider)")
                guard let defaultConfig = config.providers[config.defaultProvider] else {
                    throw WoquError.initError(.invalidProvider(config.defaultProvider))
                }
                providerConfig = defaultConfig
            }

            // get api client
            self.apiClient = APIClient(
                provider: providerConfig,
                promptTemplates: config.promptTemplates ?? [:]
            )

            // get command history
            let history = getCommandHistory(command)

            // get suggestion from api
            let suggestion: CommandSuggestion = try await getCommandSuggestionWithRetry(history: history)

            // display suggestion
            print("""
            Explanation:
            \(suggestion.explanation)
            """)

            // ask user to execute commands
            for (index, command) in suggestion.commands.enumerated() {
                print("""
                Command \(index + 1):
                \(command.command)
                Description: \(command.description)
                """)

                if !dryRun {
                    print("Execute commands? (y/n)")
                    if let input = readLine(), input.lowercased() == "y" {
                        let result = executeCommand(command.command)
                        print(result)
                    }
                }
            }


        } catch let error as WoquError {
            Logger.error(error.errorDescription ?? "")
        } catch {
            print("Error: \(error.localizedDescription)")
        }
    }

    private func getCommandSuggestionWithRetry(history: [CommandHistory]) async throws -> CommandSuggestion {
        let currentDir = FileManager.default.currentDirectoryPath

        // Get environment variables
        let environment = ProcessInfo.processInfo.environment

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
                guard let apiClient = apiClient else {
                    throw WoquError.apiError(.notInitialized)
                }

                // Get suggestion using the formatted prompt
                guard let response = try await apiClient.getCompletion(prompt: prompt) else {
                    throw WoquError.apiError(.invalidResponse)
                }

                // Validate and parse the response
                guard !response.choices.isEmpty else {
                    throw WoquError.apiError(.invalidResponse)
                }

                let suggestion = response.choices[0].message.content

                // Validate commands
                for command in suggestion.commands {
                    guard validateCommand(command.command) else {
                        throw WoquError.apiError(.invalidResponse)
                    }
                }

                return suggestion

            } catch {
                print("getCommandSuggestionWithRetry: \(error)")

                if attempt < maxRetries {
                    print("Retrying in 1 second... (attempt \(attempt)/\(maxRetries))")
                    try await Task.sleep(nanoseconds: retryDelay)
                }
            }
        }

        throw WoquError.apiError(.invalidResponse)
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
            return "Error executing command: \(result.output)"
        }
    }
}
