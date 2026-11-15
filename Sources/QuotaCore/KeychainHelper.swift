import Foundation
import Security

public enum KeychainHelper {
    /// Reads a generic password from macOS Keychain using Security framework first,
    /// falling back to `/usr/bin/security` if ACLs require the CLI utility.
    public static func readGenericPassword(service: String, account: String? = nil) -> String? {
        // Use `/usr/bin/security` CLI first since it is pre-authorized for CLI keychain items
        // without triggering modal GUI permission prompts on ad-hoc signed builds.
        return readViaSecurityCLI(service: service, account: account)
    }

    private static func readViaSecurityCLI(service: String, account: String?) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        var args = ["find-generic-password", "-s", service, "-w"]
        if let account, !account.isEmpty {
            args.append(contentsOf: ["-a", account])
        }
        process.arguments = args

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = outPipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !output.isEmpty else {
                return nil
            }
            return output
        } catch {
            return nil
        }
    }
}
