# Beira

Native macOS menu-bar utility. Swift Package Manager, SwiftUI/AppKit, a small
C bridge for private MultitouchSupport, and a platform-independent recognizer.

- Build and package: `./scripts/build.sh`. Output: `build/Beira.app`.
- Tests: `swift test`. Run before delivering recognizer changes.
- Open the packaged app for UI/hardware verification, not the unbundled executable.
- Keep generated output in ignored `.build/` and `build/` directories.
- Preserve center-origin rejection, two-finger cancellation and cancel-until-lift.
- Never retain a private contact pointer after its callback returns.
- Stop stale callbacks and release cursor anchoring on every lifecycle exit.
- Do not claim hardware-level verification from event posting or simulated contacts.
- Keep private APIs isolated in TrackpadBridge and document ABI changes.
- Do not import Slidr binaries, recovered source, licensing or assets into this project.
- Do not use GitHub Actions. Build, test, package and publish releases locally.
- Release downloads: `./scripts/release.sh` produces separate Apple Silicon and Intel ZIPs.
- Public downloads use ad-hoc signing only, without an Apple distribution certificate or notarization.
- After a release is uploaded and verified, remove local `.build/` and `build/` output as requested.
- Cleanup must preserve source, documentation, Git history and `/Applications/Beira.app`.
