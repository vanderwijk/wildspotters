import SwiftUI

/// Top-level menu opened via the hamburger icon. Hosts general information
/// about Wildspotters and links into the deeper profile panel
/// (`ProfileDrawerView`), per the "3e/4e niveau" drilldown style.
struct MenuView: View {

    @Environment(\.dismiss) private var dismiss
    @ObservedObject var authManager: AuthManager

    @State private var isProfilePresented = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color("BrandBeige")
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 14) {
                        aboutSection

                        DrilldownGroup {
                            Button {
                                isProfilePresented = true
                            } label: {
                                DrilldownRow(
                                    title: String(localized: "menu.profile.title"),
                                    subtitle: String(localized: "menu.profile.subtitle"),
                                    systemImage: "person.crop.circle"
                                )
                            }
                            .buttonStyle(.plain)
                        }
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
        .sheet(isPresented: $isProfilePresented) {
            ProfileDrawerView(authManager: authManager)
        }
    }

    private var aboutSection: some View {
        Text(LocalizedStringKey(String(localized: "menu.about.text")))
            .font(.subheadline)
            .foregroundStyle(Color("BrandDarkGray"))
            .tint(Color("BrandDarkGreen"))
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
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
