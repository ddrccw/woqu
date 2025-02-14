import Foundation
import WoquCore
import ArgumentParser

public struct AliasCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "alias",
        abstract: "Generate shell alias function"
    )

    public init() {}

    public func run() throws {
        // Create appropriate shell instance
        let shell = try ShellFactory.createShell()

        // Generate and inject shell function
        let aliasFunction = shell.generateAliasFunction(name: "woqu")
        print(aliasFunction)
    }
}
