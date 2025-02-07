//
//  File.swift
//  woqu
//
//  Created by alibaba on 2025/2/7.
//

import Foundation

actor OpenAIService: @preconcurrency APIService {
    private let provider: Provider
    init(provider: Provider) {
        self.provider = provider
    }

    @MainActor
    func getCompletion(prompt: String) async throws -> CommandSuggestion {
        // Use template if provided
        let finalPrompt = prompt

        var parameters: [String: Any] = [
            "model": provider.model,
            "messages": [
                ["role": "user", "content": finalPrompt]
            ],
            "temperature": provider.temperature,
        ]

        if provider.name != .siliconflow {
            // siliconflow not support
            parameters["response_format"] = ["type": "json_object"]
        }

        print("parameters json: \(parameters.wq_toJSONString() ?? "")")
        var request = URLRequest(url: provider.apiUrl)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(provider.apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: parameters)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw WoquError.apiError(.invalidResponse)
        }

        // Validate and parse the response
        guard let resp = OpenAIResponse(data: data),
              !resp.choices.isEmpty else {
            throw WoquError.apiError(.invalidResponse)
        }

        let suggestion = resp.choices[0].message.content
        return suggestion
    }
}
