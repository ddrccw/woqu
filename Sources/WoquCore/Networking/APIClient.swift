import Foundation

public actor APIClient {
    private let apiUrl: URL
    private let apiKey: String
    private let session: URLSession
    private let model: String
    private let temperature: Double
    private let promptTemplates: [String: String]

    public init(
        apiUrl: URL,
        apiKey: String,
        model: String,
        temperature: Double,
        promptTemplates: [String: String],
        session: URLSession = .shared
    ) {
        self.apiUrl = apiUrl
        self.apiKey = apiKey
        self.session = session
        self.model = model
        self.temperature = temperature
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
            "model": self.model,
            "messages": [
                ["role": "user", "content": finalPrompt]
            ],
            "temperature": self.temperature,
            // "response_format": ["type": "json_object"], siliconflow not support
        ]

        print("parameters json: \(parameters.wq_toJSONString() ?? "")")
        var request = URLRequest(url: apiUrl)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: parameters)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.invalidResponse
        }

        return APIResponse(data: data)
    }
}

