import Foundation
import ArgumentParser
import WoquCore
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

@main
struct WoQuCommand: AsyncParsableCommand {
    static let cnfiguration = CommandConfiguration(
        commandName: "woqu",
        abstract: "A command-line tool for intelligent command suggestions",
        discussion: """
        WoQu is an AI-powered command line assistant that:
        - Analyzes your command history and current context
        - Provides intelligent suggestions for command corrections and improvements
        - Helps automate repetitive command line tasks
        - Supports multiple shell environments (bash, zsh, fish)

        Basic usage:
        - Just run 'woqu' to get suggestions based on recent commands
        - Use -p/--provider to specify AI provider (openai, anthropic)
        - Use -h/--help to show this help message

        Example:
        $ woqu
        """
    )

    @Option(name: .shortAndLong, help: "The provider to use (deepseek, openai, anthropic)")
    var provider: ConfigManager.ProviderType?

    private var shouldExit = false

    func validate() throws {
        // 如果需要，添加自定义验证
        print("Validating options...")
    }

    func run() async throws {
        print("run...")

        // Setup signal handler
        signal(SIGINT) { _ in
            print("\nReceived interrupt signal. Exiting gracefully...")
            Darwin.exit(0)
        }

        let woqu = await Woqu()
        await woqu.run(provider: provider)
    }
}

struct CommandSuggestion: Codable {
    let explanation: String
    let commands: [Command]

    struct Command: Codable {
        let command: String
        let description: String
    }
}

@MainActor
final class Woqu {
    private let configManager = ConfigManager.shared
    private var apiClient: APIClient?
    private let maxRetries = 3
    private let retryDelay: UInt64 = 1_000_000_000 // 1 second in nanoseconds

    init() {
    }

    func run(provider: ConfigManager.ProviderType? = nil) async {
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
            guard let baseURL = URL(string: providerConfig.apiUrl) else {
                throw InitializationError.invalidAPIURL
            }

            self.apiClient = APIClient(
                baseURL: baseURL,
                apiKey: providerConfig.apiKey,
                model: providerConfig.model,
                temperature: providerConfig.temperature,
                promptTemplates: config.promptTemplates
            )

            // 3. 获取历史命令
            let history = getCommandHistory()

            // 4. 调用OpenAI API获取建议
            let suggestion = try await getCommandSuggestionWithRetry(history: history)

            // 5. 显示建议
            print("""
            Explanation:
            \(suggestion.explanation)
            """)

            for (index, command) in suggestion.commands.enumerated() {
                print("""
                Command \(index + 1):
                \(command.command)
                Description: \(command.description)
                """)
            }

            // 6. 询问用户是否执行
            print("Execute commands? (y/n)")
            if let input = readLine(), input.lowercased() == "y" {
                for command in suggestion.commands {
                    let result = executeCommand(command.command)
                    print(result)
                }
            }

        } catch ConfigManager.ConfigError.configFileNotFound {
            print("Error: Configuration file not found. Please run 'woqu setup' to configure.")
        } catch APIError.invalidResponse {
            print("Error: Invalid API response. Please check your configuration.")
        } catch APIError.noData {
            print("Error: No data received from API. Please check your internet connection.")
        } catch {
            print("Error: \(error.localizedDescription)")
        }
    }

    private func getCommandSuggestionWithRetry(history: [CommandHistory]) async throws -> CommandSuggestion {
        var lastError: Error?

        // Get current directory
        let currentDir = FileManager.default.currentDirectoryPath

        // Get environment variables
        let environment = ProcessInfo.processInfo.environment

        // Get command history with error context
        let historyWithErrors = history

        // Create prompt using template
        let prompt = AIPromptTemplate.generatePrompt(
            currentDir: currentDir,
            history: historyWithErrors.map { $0.command },
            environment: environment,
            error: historyWithErrors.last?.output ?? "",
            command: historyWithErrors.last?.command ?? ""
        )

        for attempt in 1...maxRetries {
            do {
                guard let apiClient = apiClient else {
                    throw APIError.notInitialized
                }

                // Get suggestion using the formatted prompt
                let response = try await apiClient.getCompletion(prompt: prompt)

                // Validate and parse the response
                guard !response.choices.isEmpty else {
                    throw APIError.invalidResponse
                }

                let jsonString = response.choices[0].message.content
                guard let jsonData = jsonString.data(using: String.Encoding.utf8) else {
                    throw APIError.invalidResponse
                }

                let decoder = JSONDecoder()
                let suggestion = try decoder.decode(CommandSuggestion.self, from: jsonData)

                // Validate commands
                for command in suggestion.commands {
                    guard validateCommand(command.command) else {
                        throw APIError.invalidResponse
                    }
                }

                return suggestion
            } catch {
                lastError = error
                if attempt < maxRetries {
                    print("Retrying in 1 second... (attempt \(attempt)/\(maxRetries))")
                    try await Task.sleep(nanoseconds: retryDelay)
                }
            }
        }

        throw lastError ?? APIError.invalidResponse
    }

    private func validateCommand(_ command: String) -> Bool {
        // Basic validation rules
        guard !command.isEmpty else { return false }
        guard !command.contains("rm -rf /") else { return false } // Prevent dangerous commands
        return true
    }

    private func getCommandHistory() -> [CommandHistory] {
        let shell = ShellFactory.createShell()
        return shell.getCommandHistory()
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
