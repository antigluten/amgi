//
//  SyncEndpoint.swift
//  AnkiSync
//
//  Created by Vladimir Gusev on 20.08.2026.
//

import Darwin
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
                    http:// is only allowed for local or VPN addresses \
                    (e.g. 192.168.x.x, 100.x.x.x, *.local). Use https:// \
                    for anything else.
                    """
            case .malformed:
                return "That doesn't look like a valid server address."
            }
        }
    }

    /// Trims, defaults a missing scheme to https, and allows `http://` only
    /// for private hosts.
    ///
    /// App Transport Security does not cover this traffic — sync goes out
    /// through the Rust HTTP client inside AnkiRustLib, not NSURLSession —
    /// so this host check is the only thing keeping credentials off a
    /// cleartext connection to the public internet.
    public static func normalized(_ raw: String) throws(ValidationError) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw .empty }

        let lowered = trimmed.lowercased()
        let isCleartext = lowered.hasPrefix("http://")
        let withScheme = isCleartext || lowered.hasPrefix("https://") ? trimmed : "https://" + trimmed
        guard let url = URL(string: withScheme), let host = url.host, !host.isEmpty else {
            throw .malformed
        }
        if isCleartext, !isPrivateHost(host) { throw .insecureScheme }
        return withScheme
    }

    static func isPrivateHost(_ rawHost: String) -> Bool {
        let host = rawHost.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        if let octets = ipv4Octets(host) { return isPrivateIPv4(octets) }
        if host.contains(":") { return isPrivateIPv6(host) }
        if host == "localhost" { return true }
        let privateSuffixes = [".local", ".lan", ".home.arpa", ".internal", ".ts.net"]
        if privateSuffixes.contains(where: host.hasSuffix) { return true }
        return isSingleLabelName(host)
    }

    // Leading zeros are rejected: the Rust URL parser reads "010" as octal 8,
    // so "010.0.0.1" would pass here as 10.x and connect to 8.0.0.1.
    private static func ipv4Octets(_ host: String) -> [UInt8]? {
        let parts = host.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return nil }
        var octets: [UInt8] = []
        for part in parts {
            guard !part.isEmpty, part.allSatisfy(\.isASCII), part.allSatisfy(\.isNumber),
                  part == "0" || !part.hasPrefix("0"),
                  let value = UInt8(part) else { return nil }
            octets.append(value)
        }
        return octets
    }

    private static func isPrivateIPv4(_ o: [UInt8]) -> Bool {
        switch (o[0], o[1]) {
        case (127, _), (10, _), (192, 168), (169, 254): true
        case (172, 16...31): true
        case (100, 64...127): true  // shared address space, used by Tailscale
        default: false
        }
    }

    private static func isPrivateIPv6(_ host: String) -> Bool {
        var address = in6_addr()
        guard inet_pton(AF_INET6, host, &address) == 1 else { return false }
        let bytes = withUnsafeBytes(of: address) { Array($0) }
        let isLoopback = bytes.dropLast().allSatisfy { $0 == 0 } && bytes.last == 1
        let isUniqueLocal = bytes[0] & 0xFE == 0xFC
        let isLinkLocal = bytes[0] == 0xFE && bytes[1] & 0xC0 == 0x80
        return isLoopback || isUniqueLocal || isLinkLocal
    }

    // A letter first, so numeric hosts ("134744072", "0x8080808"), which the
    // Rust URL parser treats as IPv4 addresses, never count as LAN names.
    private static func isSingleLabelName(_ host: String) -> Bool {
        guard let first = host.first, first.isASCII, first.isLetter else { return false }
        return host.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") }
    }
}
