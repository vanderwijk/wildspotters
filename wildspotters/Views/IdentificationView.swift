import SwiftUI

struct IdentificationView: View {

    @ObservedObject var authManager: AuthManager
    @StateObject private var viewModel = IdentificationViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Color("BrandDarkGreen").ignoresSafeArea()

                if viewModel.isLoading && viewModel.currentSpot == nil {
                    ProgressView(String(localized: "identification.loading"))
                        .tint(.white)
                        .foregroundStyle(.white)
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
            .navigationTitle(String(localized: "app.name"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color("BrandDarkGreen"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "common.logout")) {
                        authManager.logout()
                    }
                    .tint(Color("BrandLightGreen"))
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
        VStack(spacing: 0) {
            VideoPlayerView(url: spot.videoURL)
                .aspectRatio(16/9, contentMode: .fit)
                .accessibilityLabel(String(localized: "accessibility.videoPlayer"))

            ScrollView {
                VStack(spacing: 12) {
                    Text("identification.question")
                        .font(.headline)
                        .foregroundStyle(.white)

                    SpeciesSelectionView(
                        species: spot.speciesOptions,
                        catalog: viewModel.catalogStore.species,
                        isDisabled: viewModel.isSubmitting
                    ) { selected in
                        Task {
                            await viewModel.submitIdentification(speciesID: selected.id)
                        }
                    }

                    if viewModel.isSubmitting {
                        ProgressView()
                            .tint(.white)
                            .transition(.opacity)
                            .accessibilityLabel(String(localized: "identification.submitting"))
                    }
                }
                .padding(.vertical, 16)
            }
        }

    }

    private var emptyContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 48))
                .foregroundStyle(Color("BrandLightGreen"))
                .accessibilityHidden(true)

            Text("identification.empty.title")
                .font(.title2.bold())
                .foregroundStyle(.white)

            Text("identification.empty.message")
                .foregroundStyle(Color("BrandLightGreen").opacity(0.8))

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
                .foregroundStyle(Color("BrandLightGreen"))
                .accessibilityHidden(true)

            Text(message)
                .foregroundStyle(Color("BrandLightGreen").opacity(0.8))
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
