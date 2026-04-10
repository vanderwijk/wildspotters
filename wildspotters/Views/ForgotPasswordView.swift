import SwiftUI

struct ForgotPasswordView: View {

    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var requestSuccessful = false

    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty && !isLoading
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 32) {
                    Spacer()
                        .frame(height: geometry.size.height * 0.12)

                    // Header
                    VStack(spacing: 12) {
                        Image("Logo")
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 280)

                        Text("login.subtitle")
                            .font(.subheadline)
                            .foregroundStyle(Color("BrandDarkGray"))
                    }

                    if requestSuccessful {
                        VStack(spacing: 16) {
                            Label(String(localized: "forgotPassword.success"), systemImage: "checkmark.circle.fill")
                                .foregroundStyle(Color("BrandGreen"))
                                .font(.callout)
                                .multilineTextAlignment(.center)

                            Button { dismiss() } label: {
                                Text("forgotPassword.backToLogin")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                        }
                    } else {
                        VStack(spacing: 12) {
                            TextField(String(localized: "login.username"), text: $email)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .padding()
                                .background(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color("BrandLightGreen"), lineWidth: 1))
                                .onChange(of: email) { errorMessage = nil }
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
                                    Text("forgotPassword.button")
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(!canSubmit)

                        Button { dismiss() } label: {
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
        .animation(.default, value: requestSuccessful)
    }

    private func submit() {
        guard canSubmit else { return }
        Task {
            errorMessage = nil
            isLoading = true
            defer { isLoading = false }
            do {
                try await APIClient.shared.forgotPassword(email: email.trimmingCharacters(in: .whitespaces))
                requestSuccessful = true
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

struct ForgotPasswordView_Previews: PreviewProvider {
    static var previews: some View {
        ForgotPasswordView()
    }
}
