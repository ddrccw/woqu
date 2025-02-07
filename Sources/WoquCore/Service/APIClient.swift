import Foundation

public actor APIClient {
    private let provider: Provider
    private let session = URLSession.shared

    public init(
        provider: Provider
    ) {
        self.provider = provider
    }

    public func getCompletion(prompt: String) async throws -> CommandSuggestion? {
        switch provider.name {
        case .openai, .deepseek, .siliconflow, .alibaba:
            return try await OpenAIService(provider: provider).getCompletion(prompt: prompt)
        case .unknown:
            return nil
        }
    }
}

