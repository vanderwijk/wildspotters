import SwiftUI

/// Top-level menu opened via the hamburger icon. Hosts general information
/// about Wildspotters and links into the deeper profile panel
/// (`ProfileDrawerView`), per the "3e/4e niveau" drilldown style.
struct MenuView: View {

    @Environment(\.dismiss) private var dismiss
    @ObservedObject var authManager: AuthManager

    @State private var isProfilePresented = false
    @State private var avatarURL: URL?

    var body: some View {
        NavigationStack {
            ZStack {
                Color("BrandBeige")
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 14) {
                        DrilldownGroup {
                            Button {
                                isProfilePresented = true
                            } label: {
                                DrilldownRow(
                                    title: String(localized: "menu.profile.title"),
                                    subtitle: String(localized: "menu.profile.subtitle"),
                                    systemImage: "person.crop.circle",
                                    avatarURL: avatarURL
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        aboutSection

                        partnersSection

                        joinSection

                        Spacer(minLength: 24)

                        footerSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 48)
                }
            }
            .navigationTitle(String(localized: "menu.title"))
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
                    .accessibilityLabel(String(localized: "accessibility.closeMenu"))
                }
            }
        }
        .task {
            await loadAvatar()
        }
        .sheet(isPresented: $isProfilePresented) {
            ProfileDrawerView(authManager: authManager)
        }
    }

    private func loadAvatar() async {
        guard authManager.isAuthenticated else { return }
        do {
            let profile = try await APIClient.shared.getProfile()
            avatarURL = profile.avatar?.url ?? APIClient.fallbackAvatarURL
        } catch {
            // Silently ignore - row falls back to the default person icon.
        }
    }

    private var aboutSection: some View {
        Text(aboutAttributedText)
            .font(.subheadline)
            .foregroundStyle(Color("BrandDarkGray"))
            .tint(Color("BrandGreen"))
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .infoCardStyle()
    }

    /// Renders the about text with links styled as clearly recognizable
    /// (bold, underlined, brand-green) buttons rather than plain text.
    private var aboutAttributedText: AttributedString {
        attributedMarkdown(String(localized: "menu.about.text"))
    }

    /// "Pilotgemeenten" card listing the founding municipalities, with their
    /// logos shown side by side when available.
    private var partnersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "menu.partners.title"))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color("BrandDarkGreen"))

            Text(String(localized: "menu.partners.text"))
                .font(.subheadline)
                .foregroundStyle(Color("BrandDarkGray"))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            if !municipalityLogoNames.isEmpty {
                HStack(spacing: 20) {
                    ForEach(municipalityLogoNames, id: \.self) { name in
                        Image(name)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 32)
                    }
                }
                .padding(.top, 2)
            }
        }
        .infoCardStyle()
    }

    /// Logo asset names for the founding municipalities, filtered to only
    /// those actually present in the asset catalog.
    private var municipalityLogoNames: [String] {
        ["LogoGemeenteAlmere", "LogoGemeenteAmersfoort", "LogoGemeenteApeldoorn"]
            .filter { UIImage(named: $0) != nil }
    }

    /// "Doe ook mee" card inviting municipalities to get in touch.
    private var joinSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "menu.join.title"))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color("BrandDarkGreen"))

            Text(attributedMarkdown(String(localized: "menu.join.text")))
                .font(.subheadline)
                .foregroundStyle(Color("BrandDarkGray"))
                .tint(Color("BrandGreen"))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .infoCardStyle()
    }

    /// Parses a localized markdown string and styles any links as clearly
    /// recognizable (bold, underlined, brand-green) tappable text.
    private func attributedMarkdown(_ raw: String) -> AttributedString {
        guard var attributed = try? AttributedString(
            markdown: raw,
            options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) else {
            return AttributedString(raw)
        }

        for run in attributed.runs where run.link != nil {
            attributed[run.range].foregroundColor = Color("BrandGreen")
            attributed[run.range].underlineStyle = .single
            attributed[run.range].font = .subheadline.weight(.semibold)
        }

        return attributed
    }

    /// Small app credits footer: optional partner logo + version/build info.
    private var footerSection: some View {
        VStack(spacing: 10) {
            if UIImage(named: "DutchWallfishLogo") != nil {
                Image("DutchWallfishLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 28)
                    .opacity(0.85)
            }

            Text(appCreditLine)
                .font(.caption2)
                .foregroundStyle(Color("BrandDarkGray").opacity(0.45))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private var appCreditLine: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "-"
        return "Wildspotters · v\(version) (\(build)) · © Dutch Wallfish"
    }
}

/// Shared card styling for the info sections in `MenuView`, matching
/// `aboutSection`'s appearance.
private extension View {
    func infoCardStyle() -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .leading)
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
}

struct MenuView_Previews: PreviewProvider {
    static var previews: some View {
        MenuView(authManager: AuthManager.shared)
    }
}
