import Foundation
import Network
import AppKit

public final class GeminiOAuthLoginFlow: @unchecked Sendable {
    public init() {}

    /// Starts a loopback HTTP server on 127.0.0.1, opens the Google OAuth consent screen in the default browser,
    /// exchanges the authorization code for tokens, and stores them in `~/.gemini/oauth_creds.json`.
    public func signInWithBrowser() async throws {
        let state = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        let listener = try NWListener(using: .tcp, on: .any)

        let port: UInt16 = try await withCheckedThrowingContinuation { continuation in
            listener.stateUpdateHandler = { newState in
                switch newState {
                case .ready:
                    if let assignedPort = listener.port?.rawValue {
                        listener.stateUpdateHandler = nil
                        continuation.resume(returning: assignedPort)
                    }
                case .failed(let error):
                    listener.stateUpdateHandler = nil
                    continuation.resume(throwing: error)
                default:
                    break
                }
            }
            listener.start(queue: .global(qos: .userInitiated))
        }

        let resolvedPair = GeminiProviderClient.discoverLocalInstalledCLIClients().first
        let clientID = GeminiProviderClient.oauthClientID ?? resolvedPair?.0 ?? ""
        let clientSecret = GeminiProviderClient.oauthClientSecret ?? resolvedPair?.1 ?? ""
        guard !clientID.isEmpty, !clientSecret.isEmpty else {
            listener.cancel()
            throw QuotaFetchError.custom("Ejecutá `agy login` o `gemini` en tu terminal para autenticar tu cuenta.")
        }

        let redirectURI = "http://127.0.0.1:\(port)/oauth2callback"
        var authComps = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        authComps.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent"),
            URLQueryItem(name: "scope", value: GeminiProviderClient.oauthScopes.joined(separator: " ")),
            URLQueryItem(name: "state", value: state)
        ]

        guard let authURL = authComps.url else {
            listener.cancel()
            throw QuotaFetchError.invalidURL
        }

        _ = await MainActor.run {
            NSWorkspace.shared.open(authURL)
        }

        let code: String = try await withCheckedThrowingContinuation { continuation in
            var resumed = false
            listener.newConnectionHandler = { connection in
                connection.start(queue: .global(qos: .userInitiated))
                connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { data, _, _, _ in
                    defer {
                        connection.cancel()
                        listener.cancel()
                    }
                    guard !resumed else { return }
                    resumed = true

                    guard let data,
                          let requestStr = String(data: data, encoding: .utf8),
                          let firstLine = requestStr.components(separatedBy: "\r\n").first else {
                        continuation.resume(throwing: QuotaFetchError.custom("Respuesta OAuth vacía"))
                        return
                    }

                    let parts = firstLine.split(separator: " ")
                    guard parts.count >= 2,
                          let reqURL = URL(string: "http://127.0.0.1:\(port)\(parts[1])"),
                          let comps = URLComponents(url: reqURL, resolvingAgainstBaseURL: false) else {
                        continuation.resume(throwing: QuotaFetchError.custom("Callback OAuth inválido"))
                        return
                    }

                    let receivedState = comps.queryItems?.first(where: { $0.name == "state" })?.value
                    let receivedCode = comps.queryItems?.first(where: { $0.name == "code" })?.value

                    let html = """
                    HTTP/1.1 200 OK\r
                    Content-Type: text/html; charset=utf-8\r
                    Connection: close\r
                    \r
                    <!DOCTYPE html><html><body style="font-family:-apple-system,sans-serif;text-align:center;padding:48px;background:#111;color:#eee;">
                    <h2>¡Autenticación con Gemini completada!</h2>
                    <p>Ya podés cerrar esta pestaña y volver al widget AIQuota.</p>
                    </body></html>
                    """
                    connection.send(content: html.data(using: .utf8), completion: .contentProcessed({ _ in }))

                    if receivedState == state, let receivedCode, !receivedCode.isEmpty {
                        continuation.resume(returning: receivedCode)
                    } else {
                        continuation.resume(throwing: QuotaFetchError.custom("No se recibió código OAuth válido"))
                    }
                }
            }
        }

        let creds = try await exchangeCodeForTokens(
            code: code,
            redirectURI: redirectURI,
            clientID: clientID,
            clientSecret: clientSecret
        )
        let email = try? await GeminiProviderClient.fetchUserEmail(accessToken: creds.access_token ?? "")
        GeminiProviderClient.saveCredentials(creds, email: email)
    }

    private func exchangeCodeForTokens(
        code: String,
        redirectURI: String,
        clientID: String,
        clientSecret: String
    ) async throws -> GeminiProviderClient.StoredOAuthCreds {
        guard let url = URL(string: "https://oauth2.googleapis.com/token") else {
            throw QuotaFetchError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var comps = URLComponents()
        comps.queryItems = [
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "client_secret", value: clientSecret),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "grant_type", value: "authorization_code")
        ]
        request.httpBody = comps.percentEncodedQuery?.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw QuotaFetchError.custom("Falló el intercambio de token OAuth con Google")
        }

        struct TokenExchangeResponse: Decodable {
            let access_token: String
            let refresh_token: String?
            let expires_in: Double?
            let scope: String?
            let token_type: String?
        }

        let decoded = try JSONDecoder().decode(TokenExchangeResponse.self, from: data)
        let expiryMs = decoded.expires_in.map { (Date().timeIntervalSince1970 + $0) * 1000.0 }
        return GeminiProviderClient.StoredOAuthCreds(
            access_token: decoded.access_token,
            refresh_token: decoded.refresh_token,
            token_type: decoded.token_type ?? "Bearer",
            scope: decoded.scope,
            expiry_date: expiryMs
        )
    }
}
