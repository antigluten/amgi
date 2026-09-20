//
//  SyncEndpoint.swift
//  AnkiSync
//
//  Created by Vladimir Gusev on 20.08.2026.
//

public import Foundation

/// Normalization for the user-configured sync server URL.
///
/// Three screens let the user set this — onboarding, the sync sheet, and
/// sync settings — and each carried its own copy of the scheme handling,
/// so a fix to one never reached the other two.
public enum SyncEndpoint: Sendable {
    public enum ValidationError: LocalizedError, Sendable {
        case empty
        case insecureScheme
        case malformed

        public var errorDescription: String? {
            switch self {
            case .empty:
                return "Enter a server address."
            case .insecureScheme:
                return """
                    http:// sends your username, password, and sync key in \
                    cleartext. Use https://.
                    """
            case .malformed:
                return "That doesn't look like a valid server address."
            }
        }
    }

    /// Trims, defaults a missing scheme to https, and rejects cleartext.
    ///
    /// The `http://` rejection matters more than it looks: App Transport
    /// Security does not cover this traffic. ATS governs
    /// NSURLSession/CFNetwork, but sync goes out through the Rust HTTP
    /// client inside AnkiRustLib, so the platform provides no backstop
    /// here — credentials really would travel in the clear.
    public static func normalized(_ raw: String) throws(ValidationError) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw .empty }

        let lowered = trimmed.lowercased()
        if lowered.hasPrefix("http://") { throw .insecureScheme }

        let withScheme = lowered.hasPrefix("https://") ? trimmed : "https://" + trimmed
        guard let url = URL(string: withScheme), url.host?.isEmpty == false else {
            throw .malformed
        }
        return withScheme
    }
}
