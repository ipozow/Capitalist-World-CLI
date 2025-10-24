import Foundation
import Darwin

enum TerminalLauncher {
    private static let terminalFlagKey = "CAPITALIST_WORLD_CLI_TERMINAL"

    static func ensureInteractiveSession() {
        let environment = ProcessInfo.processInfo.environment
        if environment["CAPITALIST_DISABLE_TERMINAL"] != nil { return }
        guard environment[terminalFlagKey] == nil else { return }

        let isRunningInXcode: Bool = {
            if let service = environment["XPC_SERVICE_NAME"], service.contains("Xcode") {
                return true
            }
            if environment["XCODE_VERSION_ACTUAL"] != nil { return true }
            if environment["OS_ACTIVITY_DT_MODE"] != nil { return true }
            return false
        }()

        let isTerminalApplication = environment["TERM_PROGRAM"] != nil
        let shouldLaunchTerminal = isRunningInXcode || (isTerminalApplication == false)
        guard shouldLaunchTerminal else { return }

        let executablePath = CommandLine.arguments[0]
        let additionalArguments = CommandLine.arguments.dropFirst()
        let quotedArgs = additionalArguments.map(shellQuote).joined(separator: " ")
        let workingDirectory = FileManager.default.currentDirectoryPath

        let command = {
            var parts: [String] = ["cd", shellQuote(workingDirectory), "&&", "\(terminalFlagKey)=1", shellQuote(executablePath)]
            if quotedArgs.isEmpty == false {
                parts.append(quotedArgs)
            }
            return parts.joined(separator: " ")
        }()

        let script = """
        tell application \"Terminal\"
            activate
            do script \"\(appleScriptEscape(command))\"
        end tell
        """

        let process = Process()
        process.launchPath = "/usr/bin/osascript"
        process.arguments = ["-e", script]

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            fputs("[TerminalLauncher] Unable to open Terminal: \(error)\n", stderr)
        }

        exit(0)
    }

    private static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func appleScriptEscape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
    }
}
