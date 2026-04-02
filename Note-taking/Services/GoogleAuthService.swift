import AuthenticationServices
import CryptoKit
import Foundation
import OSLog
import Observation
import UIKit

private let log = Logger(subsystem: "notes.Note-taking", category: "GoogleAuth")

/// Handles Google OAuth2 authentication via ASWebAuthenticationSession (PKCE flow).
///
/// No Google SDK required — uses Apple's native AuthenticationServices framework.
///
/// Setup required (one-time, by developer):
///   1. Create a project at https://console.cloud.google.com
///   2. Enable the Google Calendar API
///   3. Create an OAuth 2.0 Client ID (type: iOS, bundle ID: com.prodnote.notetaking)
///   4. Replace `clientId` below with your actual client ID
///
/// User flow:
///   - Taps "Connect Google Calendar" in the app
///   - Google login sheet appears (ASWebAuthenticationSession)
///   - User signs in → returns to app automatically
///   - Tokens stored securely in Keychain
@Observable
@MainActor
final class GoogleAuthService: NSObject {

    static let shared = GoogleAuthService()

    // MARK: - Configuration
    // ⚠️ Replace with your Google Cloud Console OAuth 2.0 Client ID before shipping.
    static let clientId = "568379317963-fo3a4u7oq9n0c5khkgfjp9o85q8u6mns.apps.googleusercontent.com"
    // Google requires the reverse-client-ID redirect URI for native iOS apps (OAuth 2.0 policy).
    // Format: com.googleusercontent.apps.{CLIENT_ID_PREFIX}:/oauth2redirect
    private static let redirectURI  = "com.googleusercontent.apps.568379317963-fo3a4u7oq9n0c5khkgfjp9o85q8u6mns:/oauth2redirect"
    private static let scope        = "https://www.googleapis.com/auth/calendar.events"
    private static let authEndpoint = "https://accounts.google.com/o/oauth2/v2/auth"
    private static let tokenURL     = URL(string: "https://oauth2.googleapis.com/token")!

    // MARK: - Keychain keys
    private static let accessTokenKey  = "google_access_token"
    private static let refreshTokenKey = "google_refresh_token"

    // MARK: - State
    private(set) var isConnected: Bool = false

    private var accessToken: String?
    private var codeVerifier: String?
    private var activeSession: ASWebAuthenticationSession?

    // Set on MainActor inside connect() before session.start() is called.
    // Read via MainActor.assumeIsolated in presentationAnchor(for:), which AuthenticationServices
    // always calls on the main thread.
    private var _storedAnchor: UIWindow?

    override init() {
        super.init()
        accessToken  = KeychainHelper.read(key: Self.accessTokenKey)
        isConnected  = accessToken != nil
                    || KeychainHelper.read(key: Self.refreshTokenKey) != nil
    }

    // MARK: - Connect / Disconnect

    /// Opens the Google sign-in sheet. Call from a button action.
    func connect() async {
        // Resolve the key window for the presentation anchor.
        _storedAnchor = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }

        let verifier  = makeCodeVerifier()
        let challenge = makeCodeChallenge(from: verifier)
        codeVerifier  = verifier

        var components = URLComponents(string: Self.authEndpoint)!
        components.queryItems = [
            .init(name: "client_id",             value: Self.clientId),
            .init(name: "redirect_uri",           value: Self.redirectURI),
            .init(name: "response_type",          value: "code"),
            .init(name: "scope",                  value: Self.scope),
            .init(name: "code_challenge",         value: challenge),
            .init(name: "code_challenge_method",  value: "S256"),
            .init(name: "access_type",            value: "offline"),
            .init(name: "prompt",                 value: "consent"),
        ]
        guard let authURL = components.url else { return }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: "com.googleusercontent.apps.568379317963-fo3a4u7oq9n0c5khkgfjp9o85q8u6mns"
            ) { [weak self] callbackURL, error in
                guard let self else { continuation.resume(); return }
                if let error {
                    log.error("OAuth error: \(error.localizedDescription)")
                    continuation.resume()
                    return
                }
                guard
                    let url = callbackURL,
                    let code = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                        .queryItems?.first(where: { $0.name == "code" })?.value
                else {
                    log.error("OAuth: missing code in callback")
                    continuation.resume()
                    return
                }
                Task { @MainActor [weak self] in
                    await self?.exchangeCode(code)
                    continuation.resume()
                }
            }
            session.presentationContextProvider  = self
            session.prefersEphemeralWebBrowserSession = false
            activeSession = session
            session.start()
        }
    }

    /// Removes stored tokens and marks the service as disconnected.
    func disconnect() {
        KeychainHelper.delete(key: Self.accessTokenKey)
        KeychainHelper.delete(key: Self.refreshTokenKey)
        accessToken  = nil
        isConnected  = false
        log.info("Google Calendar: disconnected")
    }

    // MARK: - Token Access

    /// Returns a valid access token, refreshing silently if expired.
    /// Returns nil if the user is not connected or refresh fails.
    func validToken() async -> String? {
        if let token = accessToken { return token }
        guard let refresh = KeychainHelper.read(key: Self.refreshTokenKey) else { return nil }
        return await refreshToken(using: refresh)
    }

    // MARK: - Token Exchange

    private func exchangeCode(_ code: String) async {
        guard let verifier = codeVerifier else { return }
        var request = URLRequest(url: Self.tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = formBody([
            "code":          code,
            "client_id":     Self.clientId,
            "redirect_uri":  Self.redirectURI,
            "code_verifier": verifier,
            "grant_type":    "authorization_code",
        ])
        await performTokenRequest(request)
    }

    private func refreshToken(using refreshToken: String) async -> String? {
        var request = URLRequest(url: Self.tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = formBody([
            "refresh_token": refreshToken,
            "client_id":     Self.clientId,
            "grant_type":    "refresh_token",
        ])
        await performTokenRequest(request)
        return accessToken
    }

    @discardableResult
    private func performTokenRequest(_ request: URLRequest) async -> Bool {
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response  = try JSONDecoder().decode(TokenResponse.self, from: data)
            accessToken   = response.accessToken
            isConnected   = true
            KeychainHelper.save(key: Self.accessTokenKey, value: response.accessToken)
            if let refresh = response.refreshToken {
                KeychainHelper.save(key: Self.refreshTokenKey, value: refresh)
            }
            log.info("Google OAuth: token stored ✓")
            return true
        } catch {
            log.error("Google OAuth token request failed: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - PKCE

    private func makeCodeVerifier() -> String {
        var buffer = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer)
        return Data(buffer).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func makeCodeChallenge(from verifier: String) -> String {
        let hash = SHA256.hash(data: Data(verifier.utf8))
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    // MARK: - Helpers

    private func formBody(_ params: [String: String]) -> Data {
        params
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8) ?? Data()
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension GoogleAuthService: ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // AuthenticationServices always calls this on the main thread, so assumeIsolated is safe.
        MainActor.assumeIsolated {
            if let anchor = self._storedAnchor { return anchor }
            // Fallback — should never be reached since _storedAnchor is set before session.start().
            if let window = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .compactMap({ $0.keyWindow })
                .first { return window }
            let scene = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }.first!
            let fallback = UIWindow(windowScene: scene)
            return fallback
        }
    }
}

// MARK: - Token Response model

private struct TokenResponse: Decodable {
    let accessToken:  String
    let refreshToken: String?
    enum CodingKeys: String, CodingKey {
        case accessToken  = "access_token"
        case refreshToken = "refresh_token"
    }
}
