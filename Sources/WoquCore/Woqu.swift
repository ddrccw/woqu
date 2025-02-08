import Foundation
import ArgumentParser
import Darwin

final public class Woqu {
    public init() {}

    public func run(_ command: String?,
                    provider: Provider.Name? = nil,
                    dryRun: Bool) async {
        // Setup signal handler
        signal(SIGINT) { _ in
            let tip = "Received interrupt signal. Exiting gracefully..."
            Task {
                await TerminalDisplay.shared.info(tip)
            }
            Logger.info(tip)
            Darwin.exit(0)
        }

        do {
            await TerminalDisplay.shared.info("Trying to fix your command...")
            let suggestService = try await SuggestService(provider: provider)
            try await suggestService.run(command: command, dryRun: dryRun)
        } catch let error as WoquError {
            if case .commandError(let reason) = error,
               case .execNoError(_) = reason {
                await TerminalDisplay.shared.info(error.localizedDescription)
                Logger.info(error.localizedDescription)
            } else {
                await TerminalDisplay.shared.error(error.localizedDescription)
                Logger.error(error.errorDescription ?? "Unknown WoquError")
            }
        } catch {
            await TerminalDisplay.shared.error(error.localizedDescription)
            Logger.error("Error: \(error.localizedDescription)")
        }
    }
}
