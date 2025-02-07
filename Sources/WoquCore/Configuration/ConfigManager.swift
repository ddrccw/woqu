import Foundation
import Yams

public struct ConfigManager: Sendable {
    public static let shared = ConfigManager()

    private let configDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config")
        .appendingPathComponent("woqu")

    private let configFile = "settings.yml"

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
    /// ```
    public struct Configuration: Decodable, Sendable {
        public let defaultProvider: Provider.Name
        public let providers: [Provider.Name: Provider]

        enum CodingKeys: String, CodingKey {
            case defaultProvider
            case providers
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.defaultProvider = try container.decode(Provider.Name.self, forKey: .defaultProvider)

            let providersDict = try container.decode([String: ProviderData].self, forKey: .providers)
            self.providers = try providersDict.reduce(into: [Provider.Name: Provider]()) { result, pair in
                guard let providerType = Provider.Name(rawValue: pair.key) else {
                    Logger.warning("Invalid provider type: \(pair.key)")
                    return
                }
                result[providerType] = try Provider(pair.value, name: providerType)
            }
        }

        public init(defaultProvider: Provider.Name, providers: [Provider.Name: Provider], promptTemplates: [String: String]) {
            self.defaultProvider = defaultProvider
            self.providers = providers
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
            throw WoquError.configError(.fileNotFound)
        }

        let yamlString = try String(contentsOf: configPath)
        let decoder = YAMLDecoder()
        let data = yamlString.data(using: .utf8)!
        return try decoder.decode(Configuration.self, from: data)
    }

//    public func saveConfig(_ config: Configuration) throws {
//        let configPath = configDirectory.appendingPathComponent(configFile)
//        let encoder = YAMLEncoder()
//        let yamlString = try encoder.encode(config)
//        try yamlString.write(to: configPath, atomically: true, encoding: .utf8)
//    }

}
