import SwiftUI

struct ResetPasswordView: View {

    let token: String
    let login: String?
    let onReturnToLogin: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var resetSuccessful = false
    @FocusState private var focusedField: Field?

    private enum Field {
        case password
        case confirmPassword
    }

    private var canSubmit: Bool {
        !password.isEmpty
            && !confirmPassword.isEmpty
            && !isLoading
            && !resetSuccessful
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 32) {
                    Spacer()
                        .frame(height: geometry.size.height * 0.10)

                    VStack(spacing: 12) {
                        Image("Logo")
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 280)

                        Text("resetPassword.title")
                            .font(.headline)
                            .foregroundStyle(Color("BrandDarkGray"))
                    }

                    if resetSuccessful {
                        VStack(spacing: 16) {
                            Label(String(localized: "resetPassword.success"), systemImage: "checkmark.circle.fill")
                                .foregroundStyle(Color("BrandGreen"))
                                .font(.callout)
                                .multilineTextAlignment(.center)

                            Button {
                                dismiss()
                                onReturnToLogin()
                            } label: {
                                Text("forgotPassword.backToLogin")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                        }
                    } else {
                        Text("resetPassword.description")
                            .font(.subheadline)
                            .foregroundStyle(Color("BrandDarkGray").opacity(0.8))
                            .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(spacing: 12) {
                            SecureField(String(localized: "resetPassword.newPassword"), text: $password)
                                .textContentType(.newPassword)
                                .focused($focusedField, equals: .password)
                                .submitLabel(.next)
                                .padding()
                                .background(Color(.systemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color("BrandLightGreen"), lineWidth: 1))
                                .onChange(of: password) { errorMessage = nil }
                                .onSubmit { focusedField = .confirmPassword }

                            SecureField(String(localized: "resetPassword.confirmPassword"), text: $confirmPassword)
                                .textContentType(.newPassword)
                                .focused($focusedField, equals: .confirmPassword)
                                .submitLabel(.go)
                                .padding()
                                .background(Color(.systemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color("BrandLightGreen"), lineWidth: 1))
                                .onChange(of: confirmPassword) { errorMessage = nil }
                                .onSubmit { submit() }
                        }

                        if let error = errorMessage {
                            Label(error, systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                                .font(.callout)
                                .transition(.opacity)
                        }

                        Button(action: submit) {
                            Group {
                                if isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("resetPassword.button")
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(!canSubmit)

                        Button {
                            dismiss()
                            onReturnToLogin()
                        } label: {
                            Text("forgotPassword.backToLogin")
                                .font(.footnote)
                                .foregroundStyle(Color("BrandDarkGray"))
                        }
                    }
                }
                .padding(32)
                .frame(minHeight: geometry.size.height)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(
            ZStack {
                Color("BrandBeige")
                RadialGradient(
                    colors: [.clear, .black.opacity(0.12)],
                    center: .center,
                    startRadius: 50,
                    endRadius: UIScreen.main.bounds.height * 0.7
                )
            }
            .ignoresSafeArea()
        )
        .animation(.default, value: errorMessage != nil)
        .animation(.default, value: resetSuccessful)
    }

    private func submit() {
        guard canSubmit else { return }

        if let validationError = PasswordValidator.validate(password, confirmation: confirmPassword) {
            errorMessage = PasswordValidator.localizedMessage(for: validationError)
            return
        }

        Task {
            errorMessage = nil
            isLoading = true
            defer { isLoading = false }

            do {
                try await APIClient.shared.resetPassword(
                    token: token,
                    login: login,
                    password: password
                )
                resetSuccessful = true
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

struct ResetPasswordView_Previews: PreviewProvider {
    static var previews: some View {
        ResetPasswordView(token: "preview-token", login: nil, onReturnToLogin: {})
    }
}
