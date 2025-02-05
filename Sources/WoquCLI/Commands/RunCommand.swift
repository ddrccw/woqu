import Foundation
import ArgumentParser
import WoquCore
import Darwin

public struct RunCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "run",
        abstract: "Execute a command with woqu's intelligent assistance",
        discussion: """
        Executes a command while providing intelligent suggestions and error handling.
        The command will be analyzed and executed with additional context from woqu.
        """
    )

    @Option(name: .shortAndLong, help: "The provider to use (openai, deepseek, siliconflow)")
    var provider: ConfigManager.ProviderType?

    @Option(name: .shortAndLong, help: "The command to execute")
    var command: String?

    @Option(name: .shortAndLong, help: "Dry run mode")
    var dryRun: Bool = true

    public init() {}

    public func run() async throws {
        // Setup signal handler
        signal(SIGINT) { _ in
            print("\nReceived interrupt signal. Exiting gracefully...")
            Darwin.exit(0)
        }

        let woqu = await Woqu()

        await woqu.run(command, provider: provider, dryRun: dryRun)
    }
}
