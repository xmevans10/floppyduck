import AuthenticationServices
import CryptoKit
import Foundation
import Security
import UIKit

struct AppleSignInPayload {
    let identityToken: String
    let nonce: String
    let appleUserId: String
    let displayName: String?
}

@MainActor
final class AppleSignInCoordinator: NSObject {
    private var continuation: CheckedContinuation<AppleSignInPayload, Error>?
    private var currentNonce: String = ""
    private var controller: ASAuthorizationController?

    func signIn() async throws -> AppleSignInPayload {
        let nonce = Self.randomNonce()
        currentNonce = nonce

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let controller = ASAuthorizationController(authorizationRequests: [request])
            self.controller = controller
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    private static func randomNonce(length: Int = 32) -> String {
        let charset: Array<Character> = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in
                var random: UInt8 = 0
                _ = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                return random
            }

            for random in randoms {
                if remainingLength == 0 {
                    break
                }

                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }

        return result
    }

    private static func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.map { String(format: "%02x", $0) }.joined()
    }

    private func finish(with result: Result<AppleSignInPayload, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        controller = nil
        continuation.resume(with: result)
    }
}

extension AppleSignInCoordinator: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            finish(with: .failure(AuthError.signInFailed("Invalid Apple credential.")))
            return
        }

        guard let identityTokenData = credential.identityToken,
              let identityToken = String(data: identityTokenData, encoding: .utf8),
              !identityToken.isEmpty else {
            finish(with: .failure(AuthError.missingIdentityToken))
            return
        }

        let components = [credential.fullName?.givenName, credential.fullName?.familyName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let displayName = components.isEmpty ? nil : components.joined(separator: " ")

        let payload = AppleSignInPayload(
            identityToken: identityToken,
            nonce: currentNonce,
            appleUserId: credential.user,
            displayName: displayName
        )
        finish(with: .success(payload))
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithError error: Error) {
        if let appleError = error as? ASAuthorizationError, appleError.code == .canceled {
            finish(with: .failure(AuthError.canceled))
        } else {
            finish(with: .failure(AuthError.signInFailed(error.localizedDescription)))
        }
    }
}

extension AppleSignInCoordinator: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        // Try key window first, then any visible window — prevents empty anchor fallback
        if let keyWindow = scenes.flatMap(\.windows).first(where: { $0.isKeyWindow }) {
            return keyWindow
        }
        if let anyWindow = scenes.flatMap(\.windows).first {
            return anyWindow
        }
        return ASPresentationAnchor()
    }
}
