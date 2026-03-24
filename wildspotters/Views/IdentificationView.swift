import SwiftUI

struct IdentificationView: View {

    @ObservedObject var authManager: AuthManager
    @StateObject private var viewModel = IdentificationViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
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

                if viewModel.isLoading && viewModel.currentSpot == nil {
                    ProgressView(String(localized: "identification.loading"))
                        .tint(Color("BrandDarkGreen"))
                        .foregroundStyle(Color(red: 0.196, green: 0.196, blue: 0.196))
                } else if let spot = viewModel.currentSpot {
                    spotContent(spot)
                        .transition(.opacity)
                } else if viewModel.isEmpty {
                    ScrollView {
                        emptyContent
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.top, 120)
                    }
                    .refreshable {
                        await viewModel.loadNextSpot()
                    }
                } else if let error = viewModel.errorMessage {
                    errorContent(error)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color("BrandBeige").opacity(0.9), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Image("Logo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 44)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        authManager.logout()
                    } label: {
                        Image("LogoutIcon")
                            .renderingMode(.original)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .task {
                await viewModel.loadInitial()
            }
            .animation(.easeInOut(duration: 0.3), value: viewModel.currentSpot?.id)
        }
    }

    // MARK: - Subviews

    private func spotContent(_ spot: Spot) -> some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                VideoPlayerView(url: spot.videoURL)
                    .aspectRatio(16/9, contentMode: .fit)
                    .accessibilityLabel(String(localized: "accessibility.videoPlayer"))

                ScrollView {
                    VStack(spacing: 12) {
                        Text("identification.question")
                            .font(.headline)
                            .foregroundStyle(Color(red: 0.196, green: 0.196, blue: 0.196))

                        SpeciesSelectionView(
                            species: spot.speciesOptions,
                            catalog: viewModel.catalogStore.species,
                            isDisabled: viewModel.isPanelVisible
                        ) { selected in
                            Task {
                                await viewModel.submitIdentification(species: selected)
                            }
                        }
                    }
                    .padding(.vertical, 16)
                }
            }

            // Community verdict panel overlay
            if viewModel.isPanelVisible {
                CommunityVerdictPanel(
                    panelState: viewModel.panelState,
                    catalogStore: viewModel.catalogStore,
                    countdownRemaining: viewModel.countdownRemaining,
                    countdownDuration: 10,
                    onAdvance: {
                        Task { await viewModel.advanceToNextSpot() }
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.bottom, 8)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.isPanelVisible)
    }

    private var emptyContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 48))
                .foregroundStyle(Color("BrandGreen"))
                .accessibilityHidden(true)

            Text("identification.empty.title")
                .font(.title2.bold())
                .foregroundStyle(Color(red: 0.196, green: 0.196, blue: 0.196))

            Text("identification.empty.message")
                .foregroundStyle(Color(red: 0.196, green: 0.196, blue: 0.196).opacity(0.7))

            Button(String(localized: "identification.empty.button")) {
                Task { await viewModel.loadNextSpot() }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color("BrandGreen"))
        }
    }

    private func errorContent(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(Color("BrandGreen"))
                .accessibilityHidden(true)

            Text(message)
                .foregroundStyle(Color(red: 0.196, green: 0.196, blue: 0.196).opacity(0.8))
                .multilineTextAlignment(.center)

            Button(String(localized: "common.retry")) {
                Task { await viewModel.loadNextSpot() }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color("BrandGreen"))
        }
        .padding()
    }
}

#Preview {
    IdentificationView(authManager: AuthManager.shared)
}
