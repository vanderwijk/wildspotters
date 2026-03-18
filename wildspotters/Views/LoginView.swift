import SwiftUI

struct LoginView: View {

    @ObservedObject var authManager: AuthManager

    @State private var username = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var canSubmit: Bool {
        !username.trimmingCharacters(in: .whitespaces).isEmpty
            && !password.isEmpty
            && !isLoading
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 32) {
                    Spacer()
                        .frame(height: geometry.size.height * 0.12)

                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "binoculars.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(Color("BrandGreen"))

                        Text("app.name", tableName: nil, bundle: .main, comment: "App name shown on login screen")
                            .font(.largeTitle.bold())
                            .foregroundStyle(Color("BrandDarkGreen"))

                        Text("login.subtitle", tableName: nil, bundle: .main, comment: "Login screen subtitle")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    // Form fields
                    VStack(spacing: 12) {
                        TextField(String(localized: "login.username"), text: $username)
                            .textContentType(.username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding()
                            .background(Color("BrandBeige"))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .onChange(of: username) { errorMessage = nil }

                        SecureField(String(localized: "login.password"), text: $password)
                            .textContentType(.password)
                            .padding()
                            .background(Color("BrandBeige"))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .onChange(of: password) { errorMessage = nil }
                            .onSubmit { login() }
                    }

                    // Error message
                    if let error = errorMessage {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .font(.callout)
                            .transition(.opacity)
                    }

                    // Login button
                    Button(action: login) {
                        Group {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("login.button", tableName: nil, bundle: .main, comment: "Login button label")
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!canSubmit)
                }
                .padding(32)
                .frame(minHeight: geometry.size.height)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Color(.systemBackground))
        .animation(.default, value: errorMessage != nil)
    }

    private func login() {
        guard canSubmit else { return }
        Task {
            errorMessage = nil
            isLoading = true
            defer { isLoading = false }

            do {
                try await authManager.login(
                    username: username.trimmingCharacters(in: .whitespaces),
                    password: password
                )
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    LoginView(authManager: AuthManager.shared)
}
