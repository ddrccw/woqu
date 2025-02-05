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
            // "response_format": ["type": "json_object"], siliconflow not support
        ]

        print("parameters json: \(parameters.mu_toJSONString() ?? "")")
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

    enum CodingKeys: String, CodingKey {
        case message
        case finishReason = "finish_reason"
        case index
    }
}

public struct Message: Codable, Sendable {
    public let role: String
    public let content: String
}

public struct Usage: Codable, Sendable {
    public let promptTokens: Int
    public let completionTokens: Int
    public let totalTokens: Int

    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
    }
}

public enum APIError: Error {
    case notInitialized
    case invalidResponse
    case noData
    case noErrorInHistory
}


extension JSONSerialization.WritingOptions {
    // 兼容老版本用该值
    public static var mu_withoutEscapingSlashes: JSONSerialization.WritingOptions {
        if #available(iOS 13.0, *) {
            return JSONSerialization.WritingOptions.withoutEscapingSlashes
        } else {
            return JSONSerialization.WritingOptions(rawValue: UInt(1) << 3)
        }
    }
}

extension Dictionary {
    // Dictionary to data
    public func mu_toJSONData(options opt: JSONSerialization.WritingOptions = []) -> Data? {
        return try? JSONSerialization.data(withJSONObject: self, options: opt)
    }

    // Dictionay to String
    public func mu_toJSONString(options opt: JSONSerialization.WritingOptions = []) -> String? {
        guard let data = mu_toJSONData(options: opt) else {
            return nil
        }

        if #available(iOS 13.0, *) {
            return String(data: data, encoding: .utf8)
        } else {
            let ret = String(data: data, encoding: .utf8)
            if opt.contains(.mu_withoutEscapingSlashes),
               let ret = ret {
                return ret.mu_removingEscapingSlashes();
            }
            return ret
        }
    }
}


extension String {
    public func mu_toDictionary() -> [String: Any]? {
        guard let data = data(using: .utf8),
              data.count > 0 else {
            return nil
        }
        return data.mu_toDictionary()
    }

    public func mu_removingEscapingSlashes() -> String {
        return self.replacingOccurrences(of: "\\/", with: "/")
    }
}

extension Data {
    public func mu_toDictionary() -> [String: Any]? {
        guard let dict = try? JSONSerialization.jsonObject(with: self,
                                                           options: .mutableContainers),
              let dict = dict as? [String: Any] else {
            return nil
        }
        return dict
    }
}
