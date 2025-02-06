import Foundation
import ArgumentParser
import Darwin

enum InitializationError: Error {
    case invalidProvider(provider: ConfigManager.ProviderType)
    case invalidAPIURL
}

extension ConfigManager.ProviderType: ExpressibleByArgument {
    public init?(argument: String) {
        if let value = ConfigManager.ProviderType(rawValue: argument.lowercased()) {
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
                    provider: ConfigManager.ProviderType? = nil,
                    dryRun: Bool) async {
        do {
            // 1. 加载配置
            let config = try configManager.loadConfig()

            // 2. 获取provider配置
            let providerConfig: ConfigManager.Configuration.ProviderConfig
            if let provider = provider, let config = config.providers[provider] {
                providerConfig = config
            } else {
                print("Warning: Provider \(String(describing: provider)) not found in config, using default provider \(config.defaultProvider)")
                guard let defaultConfig = config.providers[config.defaultProvider] else {
                    throw InitializationError.invalidProvider(provider: config.defaultProvider)
                }
                providerConfig = defaultConfig
            }

            // 3. 初始化API客户端
            guard let apiUrl = URL(string: providerConfig.apiUrl) else {
                throw InitializationError.invalidAPIURL
            }

            self.apiClient = APIClient(
                apiUrl: apiUrl,
                apiKey: providerConfig.apiKey,
                model: providerConfig.model,
                temperature: providerConfig.temperature,
                promptTemplates: config.promptTemplates ?? [:]
            )

            // 3. 获取历史命令
            let history = getCommandHistory(command)

            // 4. 调用OpenAI API获取建议
            let suggestion: CommandSuggestion = try await getCommandSuggestionWithRetry(history: history)

            // 5. 显示建议
            print("""
            Explanation:
            \(suggestion.explanation)
            """)

            // 6. 询问用户是否执行
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


        } catch ConfigManager.ConfigError.configFileNotFound {
            print("Error: Configuration file not found. Please run 'woqu setup' to configure.")
        } catch APIError.invalidResponse {
            print("Error: Invalid API response. Please check your configuration.")
        } catch APIError.noData {
            print("Error: No data received from API. Please check your internet connection.")
        } catch APIError.noErrorInHistory(let command) {
            if let command = command {
                print("Exec \"\(command)\", no recent errors found. Skipping API request.")
            } else {
                print("No recent command errors found. Skipping API request.")
            }
        } catch APIError.execTimeout(let command) {
            print("Exec \"\(command)\" timed out. Skipping API request.")
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
            throw APIError.noErrorInHistory(command: nil)
        }

        // Skip API call if execution timeout
        guard result.exitCode != SIGTERM else {
            throw APIError.execTimeout(command: lastError.command)
        }

        guard result.exitCode != 0 else {
            throw APIError.noErrorInHistory(command: lastError.command)
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
                    throw APIError.notInitialized
                }

                // Get suggestion using the formatted prompt
                guard let response = try await apiClient.getCompletion(prompt: prompt) else {
                    throw APIError.invalidResponse
                }

                // Validate and parse the response
                guard !response.choices.isEmpty else {
                    throw APIError.invalidResponse
                }

                let suggestion = response.choices[0].message.content

                // Validate commands
                for command in suggestion.commands {
                    guard validateCommand(command.command) else {
                        throw APIError.invalidResponse
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

        throw APIError.invalidResponse
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
