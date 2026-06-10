import Foundation

/// Reads non-sensitive claims from stored JWTs for client-side session lifecycle checks.
/// Signature verification remains the server's responsibility.
enum JWTSession {

    private struct Payload: Decodable {
        let exp: TimeInterval?
    }

    static func expirationDate(for token: String) -> Date? {
        guard let exp = decodePayload(token)?.exp else { return nil }
        return Date(timeIntervalSince1970: exp)
    }

    static func isExpired(_ token: String, leeway: TimeInterval = 0) -> Bool {
        guard let expirationDate = expirationDate(for: token) else { return true }
        return expirationDate.addingTimeInterval(-leeway) <= Date()
    }

    private static func decodePayload(_ token: String) -> Payload? {
        let segments = token.split(separator: ".", omittingEmptySubsequences: false)
        guard segments.count == 3 else { return nil }

        guard let payloadData = base64URLDecode(String(segments[1])) else { return nil }
        return try? JSONDecoder().decode(Payload.self, from: payloadData)
    }

    private static func base64URLDecode(_ value: String) -> Data? {
        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padding = (4 - base64.count % 4) % 4
        if padding > 0 {
            base64.append(String(repeating: "=", count: padding))
        }
        return Data(base64Encoded: base64)
    }
}
