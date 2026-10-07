# Segno release readiness plan

This checklist records the product work needed to present Segno as a finished macOS app. The identity, About window, and Sparkle updater integration are in place; update signing and publishing remain release work.

## Current release candidate

The Segno 1.2 (build 3) source candidate is pushed to `main`. GitHub's existing 1.1 tag and release are for the earlier Marks build, so 1.2 is the next available release number. The 1.2 candidate has not been published.

Publishing is currently blocked because this environment has Apple Development certificates but no Developer ID Application identity. Sparkle's `generate_keys --account kyooni18.Segno` found an existing key whose public key matches the value embedded in the app; no new keypair was generated. A Release build with code signing disabled succeeds, but it is only compile validation and is not a distributable build.

## Product polish

- [x] Add an About window with the Segno description, version/build, project link, and support link.
- [x] Integrate Sparkle for automatic update checks and a native “Check for Updates…” install flow.
- [x] Create a calm custom DMG window layout with Segno, Applications, and a sourced music slur motif.
- [x] Generate a local Release-configuration DMG preview with `scripts/build-dmg.sh` and review the mounted Finder layout.
- [ ] Rebuild the DMG with the final Developer ID identity, notarize and staple it, then verify Gatekeeper launch before publishing.
- [ ] Publish a notarized, Developer ID signed update archive to GitHub Releases, then regenerate `appcast.xml` from the archive and release notes with Sparkle's `generate_appcast --account kyooni18.Segno` utility and commit the feed.
- [ ] Back up the existing Sparkle EdDSA private key securely. Sparkle's `generate_keys --account kyooni18.Segno` found the key and printed a public key that matches the app's `SUPublicEDKey`. Never commit or upload the private key.
- Provide user-facing release notes and a support/privacy page, and document what data Segno stores or sends.
- Finish app icon artwork and validate it at macOS Finder, Dock, and Settings sizes.

## Distribution decisions

- Confirm direct GitHub release distribution; this Sparkle integration uses the repository's raw GitHub `appcast.xml` feed. If the app is moved to the Mac App Store, remove Sparkle and use App Store delivery instead.
- Confirm the publisher name, stable reverse-DNS bundle identifier, website/domain, support address, privacy policy, license, and copyright wording.
- Review package dependencies and include their required license notices.
- Decide supported macOS versions and architectures, then verify the deployment target and build settings against that support promise.

## Release gates

- Validate a clean Release archive with the intended Developer ID or App Store signing identity and hardened runtime/sandbox settings.
- For direct distribution, notarize and staple the signed app or disk image; test Gatekeeper launch on a clean Mac account.
- Verify a real release update end-to-end from an older signed build, including appcast signature, download signature, installation, and relaunch.
- For the Mac App Store, validate the archive and complete App Store Connect metadata, privacy disclosures, screenshots, and review notes.
- Smoke-test editing, open/save, document restoration, Quick Look previews, localization, accessibility, and upgrade behavior using a clean install and an upgrade over the previous build.
- Verify version/build numbers, release notes, crash reporting/support links, and the final downloadable artifact before publishing.
