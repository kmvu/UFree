//
//  AppleSignInCoordinator.swift
//  UFree
//
//  Presents Sign in with Apple and returns an identity token + raw nonce for Firebase.
//

import AuthenticationServices
import CryptoKit
import Foundation
import UIKit

enum AppleSignInError: LocalizedError, Equatable {
    case missingIdentityToken
    case missingNonce
    case cancelled
    case presentationFailed

    var errorDescription: String? {
        switch self {
        case .missingIdentityToken:
            return "Apple did not return an identity token."
        case .missingNonce:
            return "Sign in with Apple nonce was missing."
        case .cancelled:
            return "Sign in with Apple was cancelled."
        case .presentationFailed:
            return "Unable to present Sign in with Apple."
        }
    }
}

struct AppleSignInResult: Sendable {
    let idToken: String
    let rawNonce: String
    let fullName: PersonNameComponents?
}

/// Bridges `ASAuthorizationController` into an async API for Firebase Auth.
@MainActor
final class AppleSignInCoordinator: NSObject {
    private var continuation: CheckedContinuation<AppleSignInResult, Error>?
    private var currentNonce: String?

    func signIn() async throws -> AppleSignInResult {
        try await performRequest()
    }

    private func performRequest() async throws -> AppleSignInResult {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            let nonce = Self.randomNonceString()
            currentNonce = nonce

            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = Self.sha256(nonce)

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    private func finish(_ result: Result<AppleSignInResult, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        currentNonce = nil
        continuation.resume(with: result)
    }

    // MARK: - Crypto helpers

    private static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            var randoms = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
            if status != errSecSuccess {
                fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(status)")
            }

            for random in randoms {
                if remainingLength == 0 { continue }
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
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}

extension AppleSignInCoordinator: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        Task { @MainActor in
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                finish(.failure(AppleSignInError.missingIdentityToken))
                return
            }
            guard let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8) else {
                finish(.failure(AppleSignInError.missingIdentityToken))
                return
            }
            guard let rawNonce = currentNonce else {
                finish(.failure(AppleSignInError.missingNonce))
                return
            }
            finish(.success(AppleSignInResult(
                idToken: idToken,
                rawNonce: rawNonce,
                fullName: credential.fullName
            )))
        }
    }

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        Task { @MainActor in
            let nsError = error as NSError
            if nsError.domain == ASAuthorizationError.errorDomain,
               nsError.code == ASAuthorizationError.canceled.rawValue {
                finish(.failure(AppleSignInError.cancelled))
            } else {
                finish(.failure(error))
            }
        }
    }
}

extension AppleSignInCoordinator: ASAuthorizationControllerPresentationContextProviding {
    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            if let key = scenes.flatMap(\.windows).first(where: \.isKeyWindow) {
                return key
            }
            if let first = scenes.flatMap(\.windows).first {
                return first
            }
            return ASPresentationAnchor()
        }
    }
}
