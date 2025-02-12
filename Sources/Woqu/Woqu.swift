import Foundation
import ArgumentParser
import WoquCLI

@main
struct Woqu: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "woqu",
        abstract: "Woqu command line interface",
        subcommands: [RunCommand.self, AliasCommand.self],
        defaultSubcommand: RunCommand.self
    )
}
