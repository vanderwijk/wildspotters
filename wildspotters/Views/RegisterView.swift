import SwiftUI

struct RegisterView: View {

    @ObservedObject var authManager: AuthManager
    var onShowLogin: () -> Void

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var registrationSuccessful = false

    private var canSubmit: Bool {
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty
            && !lastName.trimmingCharacters(in: .whitespaces).isEmpty
            && !email.trimmingCharacters(in: .whitespaces).isEmpty
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
                    VStack(spacing: 12) {
                        Image("Logo")
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 280)

                        Text("login.subtitle")
                            .font(.subheadline)
                            .foregroundStyle(Color(red: 0.196, green: 0.196, blue: 0.196))
                    }

                    if registrationSuccessful {
                        // Success state
                        VStack(spacing: 16) {
                            Label(String(localized: "register.success"), systemImage: "checkmark.circle.fill")
                                .foregroundStyle(Color("BrandGreen"))
                                .font(.callout)
                                .multilineTextAlignment(.center)

                            Button(action: onShowLogin) {
                                Text("register.goToLogin")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                        }
                    } else {
                        // Form fields
                        VStack(spacing: 12) {
                            TextField(String(localized: "register.firstName"), text: $firstName)
                                .textContentType(.givenName)
                                .textInputAutocapitalization(.words)
                                .padding()
                                .background(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color("BrandLightGreen"), lineWidth: 1))
                                .onChange(of: firstName) { errorMessage = nil }

                            TextField(String(localized: "register.lastName"), text: $lastName)
                                .textContentType(.familyName)
                                .textInputAutocapitalization(.words)
                                .padding()
                                .background(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color("BrandLightGreen"), lineWidth: 1))
                                .onChange(of: lastName) { errorMessage = nil }

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

                            SecureField(String(localized: "login.password"), text: $password)
                                .textContentType(.newPassword)
                                .padding()
                                .background(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color("BrandLightGreen"), lineWidth: 1))
                                .onChange(of: password) { errorMessage = nil }
                                .onSubmit { register() }
                        }

                        // Error message
                        if let error = errorMessage {
                            Label(error, systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                                .font(.callout)
                                .transition(.opacity)
                        }

                        // Register button
                        Button(action: register) {
                            Group {
                                if isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("register.button")
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(!canSubmit)

                        // Login link
                        Button(action: onShowLogin) {
                            Text("register.alreadyHaveAccount")
                                .font(.footnote)
                                .foregroundStyle(Color(red: 0.196, green: 0.196, blue: 0.196))
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
        .animation(.default, value: registrationSuccessful)
    }

    private func register() {
        guard canSubmit else { return }
        Task {
            errorMessage = nil
            isLoading = true
            defer { isLoading = false }

            do {
                try await APIClient.shared.register(
                    firstName: firstName.trimmingCharacters(in: .whitespaces),
                    lastName: lastName.trimmingCharacters(in: .whitespaces),
                    email: email.trimmingCharacters(in: .whitespaces),
                    password: password
                )
                registrationSuccessful = true
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    RegisterView(authManager: AuthManager.shared, onShowLogin: {})
}
