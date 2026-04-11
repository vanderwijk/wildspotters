# Wildspotters iOS App Overview

## Purpose
Wildspotters is an iOS app where users identify animal species from short spot videos.

Core user flow:
1. Authenticate (register/login or activation deep link)
2. Load the next spot video
3. Select a species (or skip)
4. See community verdict feedback
5. Move to the next spot

## Tech Stack
- SwiftUI app lifecycle
- Async/await networking
- WordPress backend API (`/wp-json/wildspotters/v1`)
- JWT auth token stored in Keychain

## Key App Modules

### Entry and App State
- `wildspotters/wildspottersApp.swift`
- Controls auth routing between register/login and identification flow.

### Services
- `wildspotters/Services/APIClient.swift`
  - Centralized API requests and response/error mapping.
- `wildspotters/Services/AuthManager.swift`
  - Authentication state and token login/logout flow.
- `wildspotters/Services/KeychainService.swift`
  - Secure token persistence.
- `wildspotters/Services/CatalogStore.swift`
  - Species catalog caching and image prefetch.

### Identification Experience
- `wildspotters/ViewModels/IdentificationViewModel.swift`
  - Spot loading, preloading, transition state, skip/identify submission, countdown.
- `wildspotters/Views/IdentificationView.swift`
  - Main swipe + species selection experience.
- `wildspotters/Views/SpeciesSelectionView.swift`
  - Species image grid and local image loading.
- `wildspotters/Views/VideoPlayerView.swift`
  - AVPlayer caching and playback ownership management.
- `wildspotters/Views/CommunityVerdictPanel.swift`
  - Community statistics and next-video countdown panel.

## Interaction Principles
- Swipe-left transition should feel seamless (incoming card is fully rendered as preview).
- Avoid accidental species taps during swipe gestures.
- Keep gesture handling responsive and deterministic.

## Reliability Principles
- Validate deep-link auth token with backend before marking authenticated.
- Prefer atomic writes for local cache artifacts.
- Log non-fatal persistence/keychain failures for observability.

## Code Style Expectations
- Prefer simple, explicit code over abstraction-heavy patterns.
- Keep state ownership clear (`@MainActor` for UI state mutations).
- Add comments only when behavior is non-obvious.

## Future Enhancements
- Add a map icon to the footer bar that opens a mapkit map using the stored coordinates of the location of the camera that is being viewed along with the location name and description that are stored in the WordPress database.
- Add a comment icon to the footer bar that opens a panel with all comments that have been made to this spot and allows the logged in user to add their comment.
- Fix dark mode (especially the form fields for the login and registration screens look very ugly now)
- Add a hamburger menu with access to the logout link and a profile edit.
- Add a trophy icon to the footer bar with direct access to the user rankings. Note that the ranking algorithm needs to be fixed first as the current web version is too rudimentary.