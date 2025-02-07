import Foundation

public actor APIClient {
    private let provider: Provider
    private let promptTemplates: [String: String]
    private let session = URLSession.shared

    public init(
        provider: Provider,
        promptTemplates: [String: String]
    ) {
        self.provider = provider
        self.promptTemplates = promptTemplates
    }

    public func getCompletion(prompt: String, template: String? = nil) async throws -> APIResponse? {
        // Use template if provided
        let finalPrompt: String
        if let template = template,
           let templateString = self.promptTemplates[template] {
            finalPrompt = String(format: templateString, prompt)
        } else {
            finalPrompt = prompt
        }

        let parameters: [String: Any] = [
            "model": provider.model,
            "messages": [
                ["role": "user", "content": finalPrompt]
            ],
            "temperature": provider.temperature,
            // "response_format": ["type": "json_object"], siliconflow not support
        ]

        print("parameters json: \(parameters.wq_toJSONString() ?? "")")
        var request = URLRequest(url: provider.apiUrl)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(provider.apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: parameters)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw WoquError.apiError(.invalidResponse)
        }

        return APIResponse(data: data)
    }
}

