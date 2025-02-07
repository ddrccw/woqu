import Foundation

//public struct AIRequest: Encodable {
//    public let model: String
//    public let messages: [Message]
//    public let temperature: Double?
//    public let maxTokens: Int?
//
//    public struct Message: Codable {
//        public let role: Role
//        public let content: String
//
//        public enum Role: String, Codable {
//            case system
//            case user
//            case assistant
//        }
//    }
//
//    public init(
//        model: String,
//        messages: [Message],
//        temperature: Double? = nil,
//        maxTokens: Int? = nil
//    ) {
//        self.model = model
//        self.messages = messages
//        self.temperature = temperature
//        self.maxTokens = maxTokens
//    }
//}

struct ProviderData: Codable, Sendable {
    public let apiKey: String
    public let apiUrl: String
    public let model: String
    public let temperature: Double
    enum CodingKeys: String, CodingKey {
        case apiKey
        case apiUrl
        case model
        case temperature
    }
}

public struct Provider: Sendable {
    public enum Name: String, Codable, Sendable {
        case deepseek = "deepseek"
        case openai = "openai"
        case siliconflow = "siliconflow"
        case alibaba = "alibaba"
        case unknown = "unknown"
    }

    public let apiKey: String
    public let apiUrl: URL
    public let model: String
    public let temperature: Double
    public let name: Name

    init(_ providerData: ProviderData, name: Name) throws {
        guard let apiUrl = URL(string: providerData.apiUrl) else {
            throw WoquError.configError(.invalidValue(providerData.apiUrl))
        }

        self.apiUrl = apiUrl
        apiKey = providerData.apiKey
        model = providerData.model
        temperature = providerData.temperature
        self.name = name
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

public struct CommandSuggestion: WQCodable {
    let explanation: String
    let commands: [Command]
    var think: String? // 新增字段存储思考内容

    public static func create(content: String) -> CommandSuggestion? {
        // Remove markdown code fences and trim whitespace
        var string = content
            .replacingOccurrences(of: "^```json", with: "", options: .regularExpression)
            .replacingOccurrences(of: "```$", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let think = content.extractThink();

        // remove think tag
        string = string.removeThinkTag()

        guard !string.isEmpty else {
            print("Empty content after removing markdown formatting")
            return nil
        }

        if var inst = CommandSuggestion(string: string) {
            inst.think = think
            return inst
        }

        return nil
    }

    init?(string: String, think: String) {
        self.init(string: think)
        self.think = think
    }

    struct Command: WQCodable {
        let command: String
        let description: String
    }
}
