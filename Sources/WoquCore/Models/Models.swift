import Foundation

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
