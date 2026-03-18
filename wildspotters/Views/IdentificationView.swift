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
                    emptyContent
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
                await viewModel.loadNextSpot()
            }
            .animation(.easeInOut(duration: 0.3), value: viewModel.currentSpot?.id)
        }
    }

    // MARK: - Subviews

    private func spotContent(_ spot: Spot) -> some View {
        VStack(spacing: 0) {
            VideoPlayerView(url: URL(string: spot.videoURL)!)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
                .frame(maxHeight: .infinity)

            VStack(spacing: 12) {
                Text("identification.question", tableName: nil, bundle: .main, comment: "Species question label")
                    .font(.headline)
                    .foregroundStyle(.white)

                SpeciesSelectionView(
                    species: spot.speciesOptions,
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
                }
            }
            .padding(.vertical, 16)
        }
    }

    private var emptyContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 48))
                .foregroundStyle(Color("BrandLightGreen"))

            Text("identification.empty.title", tableName: nil, bundle: .main, comment: "Empty state title")
                .font(.title2.bold())
                .foregroundStyle(.white)

            Text("identification.empty.message", tableName: nil, bundle: .main, comment: "Empty state message")
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
