import Foundation

public actor APIClient {
    private let baseURL: URL
    private let apiKey: String
    private let session: URLSession
    private let model: String
    private let temperature: Double
    private let promptTemplates: [String: String]

    public init(
        baseURL: URL,
        apiKey: String,
        model: String,
        temperature: Double,
        promptTemplates: [String: String],
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.session = session
        self.model = model
        self.temperature = temperature
        self.promptTemplates = promptTemplates
    }

    public func getCompletion(prompt: String, template: String? = nil) async throws -> APIResponse {
        // Use template if provided
        let finalPrompt: String
        if let template = template,
           let templateString = self.promptTemplates[template] {
            finalPrompt = String(format: templateString, prompt)
        } else {
            finalPrompt = prompt
        }

        let parameters: [String: Any] = [
            "model": self.model,
            "messages": [
                ["role": "user", "content": finalPrompt]
            ],
            "temperature": self.temperature,
            "response_format": ["type": "json_object"]
        ]

        var request = URLRequest(url: baseURL.appendingPathComponent("completions"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: parameters)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.invalidResponse
        }

        return try JSONDecoder().decode(APIResponse.self, from: data)
    }
}

public struct APIResponse: Codable, Sendable {
    public let id: String
    public let object: String
    public let created: Int
    public let model: String
    public let choices: [Choice]
    public let usage: Usage
}

public struct Choice: Codable, Sendable {
    public let message: Message
    public let finishReason: String
    public let index: Int
}

public struct Message: Codable, Sendable {
    public let role: String
    public let content: String
}

public struct Usage: Codable, Sendable {
    public let promptTokens: Int
    public let completionTokens: Int
    public let totalTokens: Int
}

public enum APIError: Error {
    case notInitialized
    case invalidResponse
    case noData
}
