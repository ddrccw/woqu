import Foundation

public enum ShellType: String {
    case zsh
    case bash
    case fish
}

public class ShellFactory {
    private static func detectShellType() -> ShellType {
        // Get the SHELL environment variable
        guard let shellPath = ProcessInfo.processInfo.environment["SHELL"] else {
            return .zsh // Default to zsh if SHELL is not set
        }

        // Extract the shell name from the path
        let shellName = (shellPath as NSString).lastPathComponent

        // Match against known shell types
        switch shellName {
        case "zsh":
            return .zsh
        case "bash":
            return .bash
        case "fish":
            return .fish
        default:
            return .zsh // Default to zsh for unknown shells
        }
    }

    public static func createShell(type: ShellType? = nil) -> ShellProtocol {
        let shellType = type ?? detectShellType()

        // TODO: other shell classes are generated codes
        //       which don't work as expected and require manual fix
        switch shellType {
        case .zsh:
            return ZshShell()
        case .bash:
            fallthrough
            // return BashShell()
        case .fish:
            fallthrough
            // return FishShell()
        default:
            // TODO
            return ZshShell()
        }
    }
}
