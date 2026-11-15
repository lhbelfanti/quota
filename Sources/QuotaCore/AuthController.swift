import Foundation
import AppKit

public enum AuthController {
    /// Launches login for the requested provider.
    /// - For Gemini: Runs the built-in browser OAuth loopback flow directly from the app.
    /// - For Claude: Runs `claude auth login` (which opens the browser OAuth flow) or opens Terminal if interactive input is required.
    /// - For Codex: Runs `codex login` (which opens the ChatGPT OAuth flow in the browser).
    public static func signIn(provider: AIProviderKind) async throws {
        switch provider {
        case .gemini:
            let flow = GeminiOAuthLoginFlow()
            try await flow.signInWithBrowser()
        case .claude:
            try await runCLILogin(provider: .claude)
        case .codex:
            try await runCLILogin(provider: .codex)
        }
    }

    public static func signOut(provider: AIProviderKind) async {
        switch provider {
        case .claude:
            if let bin = resolveBinary(named: "claude") {
                _ = try? await runProcess(executable: bin, arguments: ["auth", "logout"])
            }
        case .codex:
            if let bin = resolveBinary(named: "codex") {
                _ = try? await runProcess(executable: bin, arguments: ["logout"])
            }
            let authFile = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex/auth.json")
            try? FileManager.default.removeItem(at: authFile)
        case .gemini:
            let oauthFile = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".gemini/oauth_creds.json")
            try? FileManager.default.removeItem(at: oauthFile)
            let accountsFile = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".gemini/google_accounts.json")
            try? FileManager.default.removeItem(at: accountsFile)
            _ = try? await runProcess(
                executable: "/usr/bin/security",
                arguments: ["delete-generic-password", "-s", "gemini-cli-oauth", "-a", "main-account"]
            )
            _ = try? await runProcess(
                executable: "/usr/bin/security",
                arguments: ["delete-generic-password", "-s", "gemini", "-a", "antigravity"]
            )
        }
    }

    private static func runCLILogin(provider: AIProviderKind) async throws {
        switch provider {
        case .claude:
            if let bin = resolveBinary(named: "claude") {
                let status = try await runProcess(executable: bin, arguments: ["auth", "login"])
                if status != 0 {
                    openInTerminal(command: "\(bin) auth login")
                }
            } else {
                openInTerminal(command: "claude auth login")
            }
        case .codex:
            if let bin = resolveBinary(named: "codex") {
                let status = try await runProcess(executable: bin, arguments: ["login"])
                if status != 0 {
                    openInTerminal(command: "\(bin) login")
                }
            } else {
                openInTerminal(command: "codex login")
            }
        case .gemini:
            break
        }
    }

    public static func resolveBinary(named name: String) -> String? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates = [
            "\(home)/.local/bin/\(name)",
            "/opt/homebrew/bin/\(name)",
            "/usr/local/bin/\(name)",
            "/usr/bin/\(name)"
        ]
        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            return path
        }
        return nil
    }

    private static func runProcess(executable: String, arguments: [String]) async throws -> Int32 {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments

            var env = ProcessInfo.processInfo.environment
            let home = FileManager.default.homeDirectoryForCurrentUser.path
            let extraPaths = "\(home)/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
            env["PATH"] = extraPaths + ":" + (env["PATH"] ?? "")
            process.environment = env

            process.terminationHandler = { proc in
                continuation.resume(returning: proc.terminationStatus)
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private static func openInTerminal(command: String) {
        let script = """
        tell application "Terminal"
            activate
            do script "\(command.replacingOccurrences(of: "\"", with: "\\\""))"
        end tell
        """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        try? process.run()
    }
}
