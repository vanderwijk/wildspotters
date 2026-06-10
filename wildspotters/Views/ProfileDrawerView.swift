import SwiftUI

struct ProfileDrawerView: View {

    @ObservedObject var authManager: AuthManager
    let onClose: () -> Void

    @State private var profile: ProfileUser?
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var currentPassword = ""
    @State private var passwordCurrentPassword = ""
    @State private var newPassword = ""
    @State private var confirmNewPassword = ""
    @State private var deletePassword = ""
    @State private var showDeleteForm = false
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var isUpdatingPassword = false
    @State private var isDeleting = false
    @State private var feedback: Feedback?
    @FocusState private var focusedField: Field?

    private enum Field {
        case firstName
        case lastName
        case email
        case currentPassword
        case passwordCurrentPassword
        case newPassword
        case confirmNewPassword
        case deletePassword
    }

    private struct Feedback: Equatable {
        enum Kind { case success, error }
        let kind: Kind
        let message: String
    }

    private var trimmedFirstName: String {
        firstName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedLastName: String {
        lastName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isEmailChange: Bool {
        guard let profile else { return false }
        return trimmedEmail.lowercased() != profile.email.lowercased()
    }

    private var canSave: Bool {
        !trimmedFirstName.isEmpty
            && !trimmedLastName.isEmpty
            && !trimmedEmail.isEmpty
            && (!isEmailChange || !currentPassword.isEmpty)
            && !isSaving
            && !isLoading
    }

    private var canDelete: Bool {
        !deletePassword.isEmpty && !isDeleting
    }

    private var canUpdatePassword: Bool {
        !passwordCurrentPassword.isEmpty
            && !newPassword.isEmpty
            && !confirmNewPassword.isEmpty
            && !isUpdatingPassword
            && !isLoading
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(spacing: 18) {
                    if isLoading && profile == nil {
                        ProgressView()
                            .tint(Color("BrandGreen"))
                            .padding(.top, 40)
                    } else {
                        profileSection
                        feedbackView
                        passwordSection
                        deleteSection
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, focusedField == .deletePassword ? 220 : 48)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .frame(maxWidth: 340, maxHeight: .infinity)
        .background(drawerBackground)
        .clipShape(RoundedRectangle(cornerRadius: 0))
        .shadow(color: .black.opacity(0.22), radius: 20, x: -8, y: 0)
        .task {
            await loadProfile()
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color("BrandGreen").opacity(0.16))
                Text(profileInitial)
                    .font(.title2.bold())
                    .foregroundStyle(Color("BrandDarkGreen"))
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 2) {
                Text("Profiel")
                    .font(.headline)
                    .foregroundStyle(Color("BrandDarkGray"))
                Text(profile?.displayName.isEmpty == false ? profile?.displayName ?? "" : "Wildspotter")
                    .font(.subheadline)
                    .foregroundStyle(Color("BrandDarkGray").opacity(0.68))
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 16)
    }

    private var profileInitial: String {
        let source = [trimmedFirstName, trimmedLastName, profile?.displayName ?? ""]
            .first { !$0.isEmpty } ?? "W"
        return String(source.prefix(1)).uppercased()
    }

    private var profileSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Gegevens", systemImage: "person.crop.circle")

            VStack(spacing: 10) {
                drawerTextField(
                    title: "Voornaam",
                    text: $firstName,
                    contentType: .givenName,
                    focusedField: .firstName,
                    submitLabel: .next
                ) {
                    focusedField = .lastName
                }

                drawerTextField(
                    title: "Achternaam",
                    text: $lastName,
                    contentType: .familyName,
                    focusedField: .lastName,
                    submitLabel: .next
                ) {
                    focusedField = .email
                }

                drawerTextField(
                    title: "E-mailadres",
                    text: $email,
                    contentType: .emailAddress,
                    keyboardType: .emailAddress,
                    focusedField: .email,
                    submitLabel: isEmailChange ? .next : .done
                ) {
                    focusedField = isEmailChange ? .currentPassword : nil
                }

                if isEmailChange {
                    SecureField("Huidig wachtwoord", text: $currentPassword)
                        .textContentType(.password)
                        .focused($focusedField, equals: .currentPassword)
                        .submitLabel(.done)
                        .padding(12)
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color("BrandLightGreen"), lineWidth: 1))
                        .onChange(of: currentPassword) { feedback = nil }

                    Text("Na opslaan sturen we een bevestigingsmail naar je nieuwe adres. Je huidige e-mailadres blijft actief tot je bevestigt.")
                        .font(.footnote)
                        .foregroundStyle(Color("BrandDarkGray").opacity(0.68))
                }
            }

            if let pendingEmail = profile?.pendingEmail {
                Label("Emailwijziging in afwachting: \(pendingEmail)", systemImage: "envelope.badge")
                    .font(.footnote)
                    .foregroundStyle(Color("BrandDarkGreen"))
            }

            Button(action: saveProfile) {
                buttonLabel(title: "Profiel opslaan", isLoading: isSaving)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!canSave)
        }
        .drawerSectionStyle()
    }

    private var passwordSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Wachtwoord", systemImage: "key")

            SecureField("Huidig wachtwoord", text: $passwordCurrentPassword)
                .textContentType(.password)
                .focused($focusedField, equals: .passwordCurrentPassword)
                .submitLabel(.next)
                .padding(12)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color("BrandLightGreen"), lineWidth: 1))
                .onChange(of: passwordCurrentPassword) { feedback = nil }
                .onSubmit { focusedField = .newPassword }

            SecureField("Nieuw wachtwoord", text: $newPassword)
                .textContentType(.newPassword)
                .focused($focusedField, equals: .newPassword)
                .submitLabel(.next)
                .padding(12)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color("BrandLightGreen"), lineWidth: 1))
                .onChange(of: newPassword) { feedback = nil }
                .onSubmit { focusedField = .confirmNewPassword }

            SecureField("Herhaal nieuw wachtwoord", text: $confirmNewPassword)
                .textContentType(.newPassword)
                .focused($focusedField, equals: .confirmNewPassword)
                .submitLabel(.done)
                .padding(12)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color("BrandLightGreen"), lineWidth: 1))
                .onChange(of: confirmNewPassword) { feedback = nil }

            Button(action: updatePassword) {
                buttonLabel(title: "Wachtwoord opslaan", isLoading: isUpdatingPassword)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!canUpdatePassword)
        }
        .drawerSectionStyle()
    }

    private var deleteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Account", systemImage: "trash")

            if showDeleteForm {
                Text("Dit verwijdert je account direct. Vul je huidige wachtwoord in om te bevestigen.")
                    .font(.footnote)
                    .foregroundStyle(.red.opacity(0.82))

                SecureField("Huidig wachtwoord", text: $deletePassword)
                    .textContentType(.password)
                    .focused($focusedField, equals: .deletePassword)
                    .submitLabel(.done)
                    .padding(12)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.red.opacity(0.36), lineWidth: 1))
                    .onChange(of: deletePassword) { feedback = nil }

                Button(role: .destructive, action: deleteAccount) {
                    buttonLabel(title: "Account definitief verwijderen", isLoading: isDeleting)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!canDelete)

                Button("Annuleren") {
                    withAnimation {
                        showDeleteForm = false
                        deletePassword = ""
                    }
                }
                .font(.footnote)
            } else {
                Button(role: .destructive) {
                    withAnimation {
                        showDeleteForm = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        focusedField = .deletePassword
                    }
                } label: {
                    Text("Account verwijderen")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
        .drawerSectionStyle()
    }

    @ViewBuilder
    private var feedbackView: some View {
        if let feedback {
            Label(
                feedback.message,
                systemImage: feedback.kind == .success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
            )
            .font(.footnote)
            .foregroundStyle(feedback.kind == .success ? Color("BrandGreen") : .red)
            .transition(.opacity)
        }
    }

    private func sectionTitle(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color("BrandDarkGray"))
    }

    private func drawerTextField(
        title: String,
        text: Binding<String>,
        contentType: UITextContentType,
        keyboardType: UIKeyboardType = .default,
        focusedField: Field,
        submitLabel: SubmitLabel,
        onSubmit: @escaping () -> Void
    ) -> some View {
        TextField(title, text: text)
            .textContentType(contentType)
            .keyboardType(keyboardType)
            .textInputAutocapitalization(keyboardType == .emailAddress ? .never : .words)
            .autocorrectionDisabled(keyboardType == .emailAddress)
            .focused($focusedField, equals: focusedField)
            .submitLabel(submitLabel)
            .padding(12)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color("BrandLightGreen"), lineWidth: 1))
            .onChange(of: text.wrappedValue) { _, _ in feedback = nil }
            .onSubmit(onSubmit)
    }

    private func buttonLabel(title: String, isLoading: Bool) -> some View {
        Group {
            if isLoading {
                ProgressView()
                    .tint(.white)
            } else {
                Text(title)
            }
        }
    }

    private var drawerBackground: some View {
        ZStack {
            Color("BrandBeige")
            LinearGradient(
                colors: [
                    Color(.systemBackground).opacity(0.92),
                    Color("BrandBeige").opacity(0.96)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }

    private func loadProfile() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let loadedProfile = try await APIClient.shared.getProfile()
            profile = loadedProfile
            firstName = loadedProfile.firstName
            lastName = loadedProfile.lastName
            email = loadedProfile.email
            currentPassword = ""
            passwordCurrentPassword = ""
            newPassword = ""
            confirmNewPassword = ""
            feedback = nil
        } catch {
            feedback = Feedback(kind: .error, message: error.localizedDescription)
        }
    }

    private func saveProfile() {
        guard canSave else { return }

        Task {
            isSaving = true
            defer { isSaving = false }

            do {
                let response = try await APIClient.shared.updateProfile(
                    firstName: trimmedFirstName,
                    lastName: trimmedLastName,
                    email: trimmedEmail,
                    currentPassword: isEmailChange ? currentPassword : nil
                )
                profile = response.user
                firstName = response.user.firstName
                lastName = response.user.lastName
                email = response.user.email
                currentPassword = ""
                feedback = Feedback(
                    kind: .success,
                    message: response.emailChangeRequested
                        ? "Controleer je nieuwe e-mailadres om de wijziging te bevestigen."
                        : "Je profiel is bijgewerkt."
                )
            } catch {
                feedback = Feedback(kind: .error, message: error.localizedDescription)
            }
        }
    }

    private func updatePassword() {
        guard canUpdatePassword else { return }

        guard newPassword == confirmNewPassword else {
            feedback = Feedback(kind: .error, message: "De wachtwoorden komen niet overeen.")
            return
        }

        guard newPassword.count >= 8 else {
            feedback = Feedback(kind: .error, message: "Je nieuwe wachtwoord moet minimaal 8 tekens zijn.")
            return
        }

        Task {
            isUpdatingPassword = true
            defer { isUpdatingPassword = false }

            do {
                let response = try await APIClient.shared.updatePassword(
                    currentPassword: passwordCurrentPassword,
                    newPassword: newPassword
                )
                profile = response.user
                passwordCurrentPassword = ""
                newPassword = ""
                confirmNewPassword = ""
                focusedField = nil
                feedback = Feedback(kind: .success, message: "Je wachtwoord is bijgewerkt.")
            } catch {
                feedback = Feedback(kind: .error, message: error.localizedDescription)
            }
        }
    }

    private func deleteAccount() {
        guard canDelete else { return }

        Task {
            isDeleting = true
            defer { isDeleting = false }

            do {
                try await APIClient.shared.deleteProfile(currentPassword: deletePassword)
                authManager.logout()
                onClose()
            } catch {
                feedback = Feedback(kind: .error, message: error.localizedDescription)
            }
        }
    }
}

private extension View {
    func drawerSectionStyle() -> some View {
        self
            .padding(14)
            .background(Color(.systemBackground).opacity(0.78))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color("BrandLightGreen").opacity(0.45), lineWidth: 1)
            )
    }
}

struct ProfileDrawerView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileDrawerView(authManager: AuthManager.shared, onClose: {})
    }
}
