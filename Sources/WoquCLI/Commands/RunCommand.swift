import Foundation
import ArgumentParser
import WoquCore
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

extension Logger.Level: ExpressibleByArgument {
    public init?(argument: String) {
        if let value = Logger.Level(rawValue: argument.uppercased()) {
            self = value
        } else {
            return nil
        }
    }
}

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
    var provider: Provider.Name?

    @Option(name: .shortAndLong, help: "The command to execute")
    var command: String?

    @Option(name: .shortAndLong, help: "Dry run mode")
    var dryRun: Bool = false

    @Option(name: .shortAndLong, help: "Log level, e.g. debug, info, warning, error")
    var logLevel: Logger.Level?

    public init() {}

    public func run() async throws {
        if let logLevel = logLevel {
            try await Logger.$logLevel.withValue(logLevel) {
                try await internalRun()
            }
        } else {
            try await internalRun()
        }
    }

    func internalRun() async throws {
        let woqu = Woqu()

        await woqu.run(command, provider: provider, dryRun: dryRun)
    }
}
