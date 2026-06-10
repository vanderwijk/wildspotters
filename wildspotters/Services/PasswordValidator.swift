import Foundation

enum PasswordValidator {

    static let minimumLength = 8

    enum ValidationError {
        case tooShort
        case mismatch
    }

    static func validate(_ password: String, confirmation: String? = nil) -> ValidationError? {
        if password.count < minimumLength {
            return .tooShort
        }
        if let confirmation, password != confirmation {
            return .mismatch
        }
        return nil
    }

    static func localizedMessage(for error: ValidationError) -> String {
        switch error {
        case .tooShort:
            String(localized: "profile.passwordTooShort")
        case .mismatch:
            String(localized: "resetPassword.passwordMismatch")
        }
    }
}
