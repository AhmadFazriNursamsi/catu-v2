# Mobile Application — Local Invariants

Follow `../AGENTS.md` for all workflow, testing, Git, validation, and execution policy.

## Local Technical Invariants

- **Stack**: Flutter 3.x + Dart 3.x.
- **Platforms**: Android (minSdk 24, targetSdk 35) & iOS (iOS 13.0+).
- **Branding**: App display name `CATU` across Android (`AndroidManifest.xml`) and iOS (`Info.plist`).
- **Icons**: Adaptive & legacy mipmaps in Android; retina AppIcon set with non-alpha 1024x1024 marketing icon in iOS.
- **Networking**: `ApiService` targeting local host port 3005 (`10.0.10.92:3005`, `127.0.0.1:3005`).
- **Generated Code**: Never hand-edit generated files (`*.g.dart`, `*.freezed.dart`).
- **Operational Scripts**: Place component-specific scripts in `scripts/mobile/`, not in product directories.
