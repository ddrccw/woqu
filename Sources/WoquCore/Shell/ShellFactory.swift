import Foundation

public enum ShellType: String, Sendable {
    case sh
    case bash
    case zsh
    case fish
    case csh
    case tcsh
    case ksh
    case dash
    case pwsh // powershell
}

public class ShellFactory {
    // macOS requires PROC_PIDPATHINFO_MAXSIZE definition
    static let PROC_PIDPATHINFO_MAXSIZE: Int32 = 4096

    // Dictionary mapping process names to ShellType
    static let supportedShells: [String: ShellType] = [
        "bash": .bash,
        "zsh": .zsh,
        "fish": .fish,
        "csh": .csh,
        "tcsh": .tcsh,
        "ksh": .ksh,
        "dash": .dash,
        "powershell": .pwsh,
        "pwsh": .pwsh
    ]

    // Function: Get process name for given PID (works for macOS and Linux)
    static func getProcessName(pid: pid_t) -> String? {
        #if os(macOS)
        var buffer = [CChar](repeating: 0, count: Int(PROC_PIDPATHINFO_MAXSIZE))
        let result = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        if result > 0 {
            // Find the null terminator
            let length = buffer.firstIndex(of: 0)
            // Convert CChar array to [UInt8]
            let uint8Buffer = buffer[0 ..< length!].map(UInt8.init)
            let path = String(decoding: uint8Buffer, as: UTF8.self)
            let processName = URL(fileURLWithPath: path).lastPathComponent.lowercased()
            return processName
        }
        return nil
        #elseif os(Linux)
        // For Linux: Read /proc/[pid]/comm file
        let commPath = "/proc/\(pid)/comm"
        if let content = try? String(contentsOfFile: commPath).trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !content.isEmpty {
            return content
        }
        return nil
        #endif
    }

    // Function: Get parent PID for given process (works for macOS and Linux)
    static func getParentPID(pid: pid_t) -> pid_t? {
        #if os(macOS)
        var info = proc_bsdinfo()
        let size = proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, Int32(MemoryLayout<proc_bsdinfo>.size))
        if size == MemoryLayout<proc_bsdinfo>.size {
            return pid_t(info.pbi_ppid)
        }
        return nil
        #elseif os(Linux)
        // For Linux: Read /proc/[pid]/stat file
        let statPath = "/proc/\(pid)/stat"
        if let content = try? String(contentsOfFile: statPath).trimmingCharacters(in: .whitespacesAndNewlines) {
            // stat file format: pid (comm) state ppid ...
            // Find the first ')' and parse remaining fields
            if let closingParenIndex = content.firstIndex(of: ")") {
                let remaining = content[closingParenIndex...].trimmingCharacters(in: .whitespaces)
                let parts = remaining.split(separator: " ")
                if parts.count >= 2, let ppid = Int(parts[1]) {
                    return pid_t(ppid)
                }
            }
        }
        return nil
        #endif
    }

    // Function: Detect shell type by traversing process tree
    public static func detectCurrentShell() -> ShellType? {
        var currentPID = getpid()
        let visitedPIDs = NSMutableSet()

        while currentPID > 0 {
            // Prevent infinite loops
            if visitedPIDs.contains(currentPID) {
                break
            }
            visitedPIDs.add(currentPID)

            guard let procName = getProcessName(pid: currentPID) else {
                break
            }

            Logger.debug("Detected process name: \(procName)")
            if let shell = supportedShells[procName] {
                return shell
            }

            guard let parentPID = getParentPID(pid: currentPID), parentPID != currentPID else {
                break
            }

            currentPID = parentPID
        }

        return nil
    }

    public static func createShell(type: ShellType? = nil) -> Shell {
        let shellType = type ?? detectCurrentShell()
        // TODO: Other shell classes are generated code
        //       which need manual fixes to work properly
        Logger.debug("Detected shell type: \(shellType ?? .zsh)")
        switch shellType {
        case .zsh:
            return ZshShell(type: .zsh)
        case .bash:
            return BashShell(type: .bash)
        case .fish:
            fallthrough
            // return FishShell()
        default:
            // TODO
            return ZshShell(type: .zsh)
        }
    }
}
