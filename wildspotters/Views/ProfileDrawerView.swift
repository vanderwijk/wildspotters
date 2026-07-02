import SwiftUI

struct ProfileDrawerView: View {

    @Environment(\.dismiss) private var dismiss
    @ObservedObject var authManager: AuthManager

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
        NavigationStack {
            ZStack {
                Color("BrandBeige")
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 14) {
                        if isLoading && profile == nil {
                            ProgressView()
                                .tint(Color("BrandGreen"))
                                .padding(.top, 40)
                        } else {
                            profileHeader
                            profileSection
                            feedbackView
                            passwordSection
                            logoutSection
                            deleteSection
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, focusedField == .deletePassword ? 220 : 48)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(String(localized: "profile.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color("BrandBeige"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color("BrandDarkGray"))
                    .accessibilityLabel(String(localized: "accessibility.closePanel"))
                }
            }
        }
        .task {
            await loadProfile()
        }
    }

    private var profileHeader: some View {
        HStack(spacing: 14) {
            profileAvatar
                .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 4) {
                Text(profile?.displayName.isEmpty == false ? profile?.displayName ?? "" : String(localized: "profile.defaultDisplayName"))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color("BrandDarkGray"))
                    .lineLimit(2)

                if let email = profile?.email, !email.isEmpty {
                    Text(email)
                        .font(.subheadline)
                        .foregroundStyle(Color("BrandDarkGray").opacity(0.58))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color("BrandDarkGreen").opacity(0.08), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var profileAvatar: some View {
        AsyncImage(url: profile?.avatar?.url ?? APIClient.fallbackAvatarURL) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            case .failure:
                AsyncImage(url: APIClient.fallbackAvatarURL) { fallbackPhase in
                    switch fallbackPhase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .empty:
                        ProgressView()
                            .tint(Color("BrandGreen"))
                    default:
                        profileInitialAvatar
                    }
                }
            case .empty:
                ProgressView()
                    .tint(Color("BrandGreen"))
            @unknown default:
                profileInitialAvatar
            }
        }
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color("BrandLightGreen").opacity(0.55), lineWidth: 2)
        )
        .accessibilityLabel(profile?.avatar?.alt ?? "")
    }

    private var profileInitialAvatar: some View {
        ZStack {
            Circle()
                .fill(Color("BrandGreen").opacity(0.16))
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 40, weight: .regular))
                .foregroundStyle(Color("BrandDarkGreen"))
        }
    }

    private var profileSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(String(localized: "profile.section.details"), systemImage: "person.crop.circle")

            VStack(spacing: 10) {
                drawerTextField(
                    title: String(localized: "register.firstName"),
                    text: $firstName,
                    contentType: .givenName,
                    focusedField: .firstName,
                    submitLabel: .next
                ) {
                    focusedField = .lastName
                }

                drawerTextField(
                    title: String(localized: "register.lastName"),
                    text: $lastName,
                    contentType: .familyName,
                    focusedField: .lastName,
                    submitLabel: .next
                ) {
                    focusedField = .email
                }

                drawerTextField(
                    title: String(localized: "profile.email"),
                    text: $email,
                    contentType: .emailAddress,
                    keyboardType: .emailAddress,
                    focusedField: .email,
                    submitLabel: isEmailChange ? .next : .done
                ) {
                    focusedField = isEmailChange ? .currentPassword : nil
                }

                if isEmailChange {
                    SecureField(String(localized: "profile.currentPassword"), text: $currentPassword)
                        .textContentType(.password)
                        .focused($focusedField, equals: .currentPassword)
                        .submitLabel(.done)
                        .padding(12)
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color("BrandLightGreen"), lineWidth: 1))
                        .onChange(of: currentPassword) { feedback = nil }

                    Text("profile.emailChangeNotice")
                        .font(.footnote)
                        .foregroundStyle(Color("BrandDarkGray").opacity(0.68))
                }
            }

            if let pendingEmail = profile?.pendingEmail {
                Label {
                    Text("profile.pendingEmailChange \(pendingEmail)")
                } icon: {
                    Image(systemName: "envelope.badge")
                }
                .font(.footnote)
                .foregroundStyle(Color("BrandDarkGreen"))
            }

            Button(action: saveProfile) {
                buttonLabel(title: String(localized: "profile.saveButton"), isLoading: isSaving)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color("BrandGreen"))
            .controlSize(.large)
            .disabled(!canSave)
        }
        .panelSectionStyle()
    }

    private var passwordSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(String(localized: "profile.section.password"), systemImage: "key")

            SecureField(String(localized: "profile.currentPassword"), text: $passwordCurrentPassword)
                .textContentType(.password)
                .focused($focusedField, equals: .passwordCurrentPassword)
                .submitLabel(.next)
                .padding(12)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color("BrandLightGreen"), lineWidth: 1))
                .onChange(of: passwordCurrentPassword) { feedback = nil }
                .onSubmit { focusedField = .newPassword }

            SecureField(String(localized: "resetPassword.newPassword"), text: $newPassword)
                .textContentType(.newPassword)
                .focused($focusedField, equals: .newPassword)
                .submitLabel(.next)
                .padding(12)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color("BrandLightGreen"), lineWidth: 1))
                .onChange(of: newPassword) { feedback = nil }
                .onSubmit { focusedField = .confirmNewPassword }

            SecureField(String(localized: "resetPassword.confirmPassword"), text: $confirmNewPassword)
                .textContentType(.newPassword)
                .focused($focusedField, equals: .confirmNewPassword)
                .submitLabel(.done)
                .padding(12)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color("BrandLightGreen"), lineWidth: 1))
                .onChange(of: confirmNewPassword) { feedback = nil }

            Button(action: updatePassword) {
                buttonLabel(title: String(localized: "profile.savePasswordButton"), isLoading: isUpdatingPassword)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color("BrandGreen"))
            .controlSize(.large)
            .disabled(!canUpdatePassword)
        }
        .panelSectionStyle()
    }

    private var logoutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(String(localized: "profile.section.session"), systemImage: "rectangle.portrait.and.arrow.right")

            Button {
                dismiss()
                authManager.logout()
            } label: {
                Label(String(localized: "common.logout"), systemImage: "rectangle.portrait.and.arrow.right")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .panelSectionStyle()
    }

    private var deleteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(String(localized: "profile.section.account"), systemImage: "trash")

            if showDeleteForm {
                Text("profile.deleteWarning")
                    .font(.footnote)
                    .foregroundStyle(.red.opacity(0.82))

                SecureField(String(localized: "profile.currentPassword"), text: $deletePassword)
                    .textContentType(.password)
                    .focused($focusedField, equals: .deletePassword)
                    .submitLabel(.done)
                    .padding(12)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.red.opacity(0.36), lineWidth: 1))
                    .onChange(of: deletePassword) { feedback = nil }

                Button(role: .destructive, action: deleteAccount) {
                    buttonLabel(title: String(localized: "profile.deleteConfirmButton"), isLoading: isDeleting)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!canDelete)

                Button {
                    withAnimation {
                        showDeleteForm = false
                        deletePassword = ""
                    }
                } label: {
                    Text("profile.cancel")
                }
                .font(.footnote)
            } else {
                Button(role: .destructive) {
                    withAnimation {
                        showDeleteForm = true
                    }
                    Task {
                        try? await Task.sleep(for: .milliseconds(150))
                        focusedField = .deletePassword
                    }
                } label: {
                    Text("profile.deleteButton")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
        .panelSectionStyle()
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
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
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
                        ? String(localized: "profile.emailChangeConfirm")
                        : String(localized: "profile.updated")
                )
            } catch {
                feedback = Feedback(kind: .error, message: error.localizedDescription)
            }
        }
    }

    private func updatePassword() {
        guard canUpdatePassword else { return }

        if let validationError = PasswordValidator.validate(newPassword, confirmation: confirmNewPassword) {
            feedback = Feedback(kind: .error, message: PasswordValidator.localizedMessage(for: validationError))
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
                feedback = Feedback(kind: .success, message: String(localized: "profile.passwordUpdated"))
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
                dismiss()
            } catch {
                feedback = Feedback(kind: .error, message: error.localizedDescription)
            }
        }
    }
}

private extension View {
    func panelSectionStyle() -> some View {
        self
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.72))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color("BrandDarkGreen").opacity(0.08), lineWidth: 1)
            )
    }
}

struct ProfileDrawerView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileDrawerView(authManager: AuthManager.shared)
    }
}
