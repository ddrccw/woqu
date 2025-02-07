import Foundation
import ArgumentParser
import Darwin

@MainActor
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
            print("Error: \(error.localizedDescription)")
        }
    }
}
