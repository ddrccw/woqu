import Foundation

public struct AIRequest: Encodable {
    public let model: String
    public let messages: [Message]
    public let temperature: Double?
    public let maxTokens: Int?

    public struct Message: Codable {
        public let role: Role
        public let content: String

        public enum Role: String, Codable {
            case system
            case user
            case assistant
        }
    }

    public init(
        model: String,
        messages: [Message],
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) {
        self.model = model
        self.messages = messages
        self.temperature = temperature
        self.maxTokens = maxTokens
    }
}

public struct APIResponse: WQCodable {
    public let id: String
    public let object: String
    public let created: Int
    public let model: String
    public let choices: [Choice]
    public let usage: Usage
}

public struct Choice: WQCodable {
    public let message: Message
    public let finishReason: String
    public let index: Int

    enum CodingKeys: String, CodingKey {
        case message
        case finishReason = "finish_reason"
        case index
    }
}

public struct Message: WQCodable {
    public let role: String
    public let content: CommandSuggestion

    public init(role: String, content: CommandSuggestion) {
        self.role = role
        self.content = content
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.role = try container.decode(String.self, forKey: .role)

        // Decode and sanitize content string
        let rawString = try container.decode(String.self, forKey: .content)

        // Remove markdown code fences and trim whitespace
        let sanitizedString = rawString
            .replacingOccurrences(of: "^```json", with: "", options: .regularExpression)
            .replacingOccurrences(of: "```$", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !sanitizedString.isEmpty else {
            throw DecodingError.dataCorruptedError(
                forKey: .content,
                in: container,
                debugDescription: "Empty content after removing markdown formatting"
            )
        }

        guard let suggestion = CommandSuggestion(string: sanitizedString) else {
            throw DecodingError.dataCorruptedError(
                forKey: .content,
                in: container,
                debugDescription: "Failed to decode content as CommandSuggestion"
            )
        }

        self.content = suggestion
    }
}

public struct Usage: WQCodable {
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
    case noErrorInHistory(command: String?)
    case execTimeout(command: String)
}

public struct CommandSuggestion: WQCodable {
    let explanation: String
    let commands: [Command]

    struct Command: WQCodable {
        let command: String
        let description: String
    }
}
