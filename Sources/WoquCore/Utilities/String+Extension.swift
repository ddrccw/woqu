import Foundation

extension String {
    func removeJsonMarkdownTag() -> String {
        return self
            .replacingOccurrences(of: "^```json", with: "", options: .regularExpression)
            .replacingOccurrences(of: "```$", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

    }

    // some llms like deepseek-r1 will return <think>xxx</think>
    // just remove <think>(.*?)</think>
    func removeThinkTag() -> String {
        return self
            .replacingOccurrences(of: "<think>(.*?)</think>", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // some llms like deepseek-r1 will return <think>xxx</think>
    func extractThink() -> String? {
        // Define the regular expression pattern to match <think>xxx</think>
        let pattern = "<think>(.*?)</think>"

        // Create a regular expression object
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return nil
        }

        // Find the first match in the string
        let range = NSRange(location: 0, length: self.utf16.count)
        if let match = regex.firstMatch(in: self, options: [], range: range) {
            // Extract the content inside the <think> tags
            let thinkRange = match.range(at: 1)
            if let swiftRange = Range(thinkRange, in: self) {
                return String(self[swiftRange])
            }
        }

        // Return nil if no match is found
        return nil
    }
}
