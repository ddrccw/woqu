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

public struct AIResponse: Decodable {
    public let id: String
    public let object: String
    public let created: Int
    public let model: String
    public let choices: [Choice]
    public let usage: Usage

    public struct Choice: Decodable {
        public let message: Message
        public let finishReason: String?

        public struct Message: Decodable {
            public let role: AIRequest.Message.Role
            public let content: String
        }
    }

    public struct Usage: Decodable {
        public let promptTokens: Int
        public let completionTokens: Int
        public let totalTokens: Int
    }
}
