//
//  File.swift
//  woqu
//
//  Created by ddrccw on 2025/2/7.
//

import Foundation

actor OpenAIService: APIService {
    private let provider: Provider
    init(provider: Provider) {
        self.provider = provider
    }

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

        if ![.siliconflow, .alibaba].contains(provider.name) {
            // some providers do not support response_format well
            parameters["response_format"] = ["type": "json_object"]
        }

        Logger.debug("parameters json: \(parameters.wq_toDebugJSONString() ?? "")")
        Logger.debug("prompt: \(finalPrompt)")
        var request = URLRequest(url: provider.apiUrl)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(provider.apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: parameters)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw WoquError.apiError(.invalidResponse("invalid response"))
        }

        guard httpResponse.statusCode == 200 else {
            throw WoquError.apiError(.statusCode(httpResponse.statusCode))
        }

        // Validate and parse the response
        guard let resp = OpenAIResponse(data: data),
              !resp.choices.isEmpty else {
            let dataStr = String(data: data, encoding: .utf8) ?? ""
            throw WoquError.apiError(.invalidResponse(dataStr))
        }

        let suggestion = resp.choices[0].message.content
        return suggestion
    }
}
