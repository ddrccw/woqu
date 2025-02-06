public enum WoquError: Error {
    // Network related errors
    public enum Network: Error {
        case invalidURL
        case requestFailed(Error)
        case invalidResponse
        case statusCode(Int)
        case noData
    }

    // Configuration related errors
    public enum Configuration: Error {
        case missingKey(String)
        case invalidValue(String)
        case fileNotFound
    }

    // Shell/Command related errors
    public enum Shell: Error {
        case commandFailed(String)
        case timeout(String)
        case invalidCommand
    }

    // API related errors
    public enum API: Error {
        case notInitialized
        case invalidRequest
        case invalidResponse
        case parsingError
    }

    // General errors
    case unknownError
    case custom(String)
}
