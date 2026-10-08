# Segno release readiness plan

This checklist records the product work needed to present Segno as a finished macOS app. Segno 1.2 is a GitHub draft while the app is rebuilt without Sparkle.

## Current release candidate

The existing GitHub draft contains Segno 1.2 (build 3), an ad-hoc signed app that fails to launch because Sparkle's embedded framework cannot pass dyld library validation without a Team ID. Build 4 removes Sparkle and its feed. The app remains ad-hoc signed and not notarized, so macOS may require users to approve it on first launch.

## Product polish

- [x] Add an About window with the Segno description, version/build, project link, and support link.
- [x] Create a calm custom DMG window layout with Segno, Applications, and a sourced music slur motif.
- [x] Generate a local Release-configuration DMG preview with `scripts/build-dmg.sh` and review the mounted Finder layout.
- [ ] Rebuild the DMG and ZIP without Sparkle, confirm the app launches, then replace the draft assets and publish the GitHub release.
- [ ] For a future signed release, build the DMG with a Developer ID identity, notarize and staple it, then verify Gatekeeper launch before publishing.
- Provide user-facing release notes and a support/privacy page, and document what data Segno stores or sends.
- Finish app icon artwork and validate it at macOS Finder, Dock, and Settings sizes.

## Distribution decisions

- [x] Use direct GitHub release distribution with manual updates. If the app is moved to the Mac App Store, use App Store delivery instead.
- Confirm the publisher name, stable reverse-DNS bundle identifier, website/domain, support address, privacy policy, license, and copyright wording.
- Review package dependencies and include their required license notices.
- Decide supported macOS versions and architectures, then verify the deployment target and build settings against that support promise.

## Release gates

- Validate a clean Release archive with the intended Developer ID or App Store signing identity and hardened runtime/sandbox settings.
- For direct distribution, notarize and staple the signed app or disk image; test Gatekeeper launch on a clean Mac account.
- For the Mac App Store, validate the archive and complete App Store Connect metadata, privacy disclosures, screenshots, and review notes.
- Smoke-test editing, open/save, document restoration, Quick Look previews, localization, accessibility, and upgrade behavior using a clean install and an upgrade over the previous build.
- Verify version/build numbers, release notes, crash reporting/support links, and the final downloadable artifact before publishing.
