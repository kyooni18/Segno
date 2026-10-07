# Segno release readiness plan

This checklist records the product work needed to present Segno as a finished macOS app. The identity, About window, and manual update check are now in place; distribution and signing decisions remain open.

## Product polish

- [x] Add an About window with the Segno description, version/build, project link, and support link.
- [x] Add a Software Update window and menu action that checks the latest stable GitHub release and opens its release page for notes and download.
- [ ] Choose distribution. The current updater assumes direct downloads from this repository's GitHub Releases; use the Mac App Store's built-in update flow instead if App Store distribution is selected.
- Provide user-facing release notes and a support/privacy page, and document what data Segno stores or sends.
- Finish app icon artwork and validate it at macOS Finder, Dock, and Settings sizes.

## Distribution decisions

- Confirm direct GitHub release distribution or choose the Mac App Store; this determines update delivery, sandbox capabilities, signing, notarization, and purchase/support flows.
- Confirm the publisher name, stable reverse-DNS bundle identifier, website/domain, support address, privacy policy, license, and copyright wording.
- Review package dependencies and include their required license notices.
- Decide supported macOS versions and architectures, then verify the deployment target and build settings against that support promise.

## Release gates

- Validate a clean Release archive with the intended Developer ID or App Store signing identity and hardened runtime/sandbox settings.
- For direct distribution, notarize and staple the signed app or disk image; test Gatekeeper launch on a clean Mac account.
- For the Mac App Store, validate the archive and complete App Store Connect metadata, privacy disclosures, screenshots, and review notes.
- Smoke-test editing, open/save, document restoration, Quick Look previews, localization, accessibility, and upgrade behavior using a clean install and an upgrade over the previous build.
- Verify version/build numbers, release notes, crash reporting/support links, and the final downloadable artifact before publishing.
