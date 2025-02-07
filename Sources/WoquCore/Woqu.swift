import Foundation
import ArgumentParser
import Darwin

final public class Woqu {
    public init() {}

    public func run(_ command: String?,
                    provider: Provider.Name? = nil,
                    dryRun: Bool) async {
        do {
            let suggestService = try SuggestService(provider: provider)
            try await suggestService.run(command: command, dryRun: dryRun)
        } catch let error as WoquError {
            if case .commandError(let reason) = error,
               case .execNoError(_) = reason {
                Logger.info(error.localizedDescription)
            } else {
                Logger.error(error.errorDescription ?? "Unknown WoquError")
            }
        } catch {
            Logger.error("Error: \(error.localizedDescription)")
        }
    }
}
