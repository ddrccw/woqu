import Foundation

public enum ShellType: String {
    case zsh
    // case bash
    // case fish
}

public class ShellFactory {
    public static func createShell(type: ShellType = .zsh) -> ShellProtocol {
        switch type {
        case .zsh:
            return ZshShell()
            /*
             case .bash:
             return BashShell()
             case .fish:
             return FishShell()
             */
        }
    }
}
