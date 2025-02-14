//
//  File.swift
//  woqu
//
//  Created by ddrccw on 2025/2/7.
//

import Foundation

public struct OpenAIResponse: WQCodable {
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
        guard let suggestion = CommandSuggestion.create(content: rawString) else {
            throw WoquError.apiError(.parsingError("Failed to decode content as CommandSuggestion"))
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
