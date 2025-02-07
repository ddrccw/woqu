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
            Logger.error(error.errorDescription ?? "")
        } catch {
            Logger.error("Error: \(error.localizedDescription)")
        }
    }
}
