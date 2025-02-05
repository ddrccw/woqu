import Foundation
import Yams

@MainActor
public struct ConfigManager: Sendable {
    public static let shared = ConfigManager()

    private let configDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config")
        .appendingPathComponent("woqu")

    private let configFile = "settings.yml"

    public enum ProviderType: String, Codable, Sendable {
        case openai = "openai"
        case deepseek = "deepseek"
        case siliconflow = "siliconflow"
        case alibaba = "alibaba"
    }

    /// Configuration structure supporting multiple AI providers
    ///
    /// Example configuration:
    /// ```yaml
    /// defaultProvider: "openai"
    /// providers:
    ///   openai:
    ///     apiKey: "your-api-key"
    ///     apiUrl: "https://api.openai.com/v1"
    ///     model: "gpt-4"
    ///     temperature: 0.7
    ///   anthropic:
    ///     apiKey: "your-api-key"
    ///     apiUrl: "https://api.anthropic.com/v1"
    ///     model: "claude-2"
    ///     temperature: 0.7
    /// promptTemplates:
    ///   default: "You are a helpful assistant"
    /// ```
    public struct Configuration: Codable, Sendable {
        public let defaultProvider: ProviderType
        public let providers: [ProviderType: ProviderConfig]
        public let promptTemplates: [String: String]?

        enum CodingKeys: String, CodingKey {
            case defaultProvider
            case providers
            case promptTemplates
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.defaultProvider = try container.decode(ProviderType.self, forKey: .defaultProvider)

            // Custom decoding for providers dictionary
            let providersDict = try container.decode([String: ProviderConfig].self, forKey: .providers)
            self.providers = try providersDict.reduce(into: [ProviderType: ProviderConfig]()) { result, pair in
                guard let providerType = ProviderType(rawValue: pair.key) else {
                    throw DecodingError.dataCorruptedError(
                        forKey: .providers,
                        in: container,
                        debugDescription: "Invalid provider type: \(pair.key)"
                    )
                }
                result[providerType] = pair.value
            }

            self.promptTemplates = try container.decodeIfPresent([String: String].self, forKey: .promptTemplates)
        }

        public struct ProviderConfig: Codable, Sendable {
            public let apiKey: String
            public let apiUrl: String
            public let model: String
            public let temperature: Double

            public init(apiKey: String, apiUrl: String, model: String, temperature: Double) {
                self.apiKey = apiKey
                self.apiUrl = apiUrl
                self.model = model
                self.temperature = temperature
            }
        }

        public init(defaultProvider: ProviderType, providers: [ProviderType: ProviderConfig], promptTemplates: [String: String]) {
            self.defaultProvider = defaultProvider
            self.providers = providers
            self.promptTemplates = promptTemplates
        }
    }

    public init() {
        // 确保配置目录存在
        try? FileManager.default.createDirectory(
            at: configDirectory,
            withIntermediateDirectories: true
        )
    }

    public func loadConfig() throws -> Configuration {
        let configPath = configDirectory.appendingPathComponent(configFile)

        guard FileManager.default.fileExists(atPath: configPath.path) else {
            throw ConfigError.configFileNotFound
        }

        let yamlString = try String(contentsOf: configPath)
        let decoder = YAMLDecoder()
        let data = yamlString.data(using: .utf8)!
        return try decoder.decode(Configuration.self, from: data)
    }

    public func saveConfig(_ config: Configuration) throws {
        let configPath = configDirectory.appendingPathComponent(configFile)
        let encoder = YAMLEncoder()
        let yamlString = try encoder.encode(config)
        try yamlString.write(to: configPath, atomically: true, encoding: .utf8)
    }

    public enum ConfigError: Error {
        case configFileNotFound
        case invalidConfigFormat
        case missingRequiredFields
    }
}
