import Foundation

public enum WoquError: Error, LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .initError(let reason):
            return reason.errorDescription
        case .configError(let reason):
            return reason.errorDescription
        case .commandError(let reason):
            return reason.errorDescription
        case .apiError(let reason):
            return reason.errorDescription
        case .unknown:
            return "An unknown error occurred"
        }
    }

    case initError(InitErrorReason)
    case configError(ConfigErrorReason)
    case commandError(CommandErrorReason)
    case apiError(APIErrorReason)
    case unknown


    // Initialization related errors
    public enum InitErrorReason: LocalizedError {
        case invalidProvider(Provider.Name)

        public var errorDescription: String? {
            switch self {
            case .invalidProvider(let provider):
                return "Invalid provider: \(provider.rawValue)"
            }
        }
    }

    // Configuration related errors
    public enum ConfigErrorReason: LocalizedError {
        public var errorDescription: String? {
            switch self {
            case .invalidProvider(let provider):
                return "Invalid provider: \(provider.rawValue)"
            case .invalidValue(let value):
                return "Invalid configuration value: \(value)"
            case .fileNotFound:
                return "Configuration file not found"
            case .parsingError(let detail):
                return "Error parsing configuration file: \(detail)"
            }
        }

        case invalidProvider(Provider.Name)
        case invalidValue(String)
        case fileNotFound
        case parsingError(String)
    }

    // Shell/Command related errors
    public enum CommandErrorReason: LocalizedError {
        public var errorDescription: String? {
            switch self {
            case .suggestFailed(let command):
                return "Command failed: \(command)"
            case .timeout(let command):
                return "Command timed out: \(command)"
            case .invalidCommand:
                return "Invalid command provided"
            case .execNoError(let command):
                if let command = command {
                    return "Exec \"\(command)\", no recent errors found"
                } else {
                    return "No recent command errors found"
                }
            }
        }
        case suggestFailed(String)
        case timeout(command: String)
        case invalidCommand(String)
        case execNoError(command: String? = nil)
    }

    // API related errors
    public enum APIErrorReason: LocalizedError {
        public var errorDescription: String? {
            switch self {
            case .notInitialized:
                return "API not properly initialized"
            case .invalidResponse:
                return "Invalid API response"
            case .parsingError(let detail):
                return "Error parsing API response: \(detail)"
            case .statusCode(let code):
                return "Received unexpected status code: \(code)"
            case .providerNotSupported(let provider):
                return "Provider not supported: \(provider)"
            }
        }
        case notInitialized
        case invalidResponse
        case parsingError(String)
        case statusCode(Int)
        case providerNotSupported(String)
    }

}
