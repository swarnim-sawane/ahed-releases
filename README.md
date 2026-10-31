# Ahed private alpha releases

Ahed helps you write useful, context-aware requests in supported AI composers: autocomplete,
next-step suggestions, Enhance and Generate.

This repository contains reviewed macOS release downloads, update-feed files, checksums and
matching corresponding source. Ahed's private development history and signing keys are not here.

## Before installing

- Access is invite-only. Downloading the app does not grant online assistance.
- Apple Silicon Mac, macOS 14 or later. These alpha builds are self-signed and not notarized.
- Install with one command in Terminal (downloads the latest release, checks it, puts it in
  Applications and opens it). It removes the downloaded app's quarantine flag because these
  alpha builds are not notarized. It may ask for your Mac password to write to Applications.
  Do not re-sign the app. You can [read the installer](install.sh) before running it.

  ```
  curl -fsSL https://raw.githubusercontent.com/swarnim-sawane/ahed-releases/main/install.sh | bash
  ```

  The installer shows compact download percentages and installation progress, detects existing
  installs and preserves your account and settings. It uses plain output when redirected;
  set `NO_COLOR=1` to disable colour.
  Nothing appears while typing your Mac password at the authorization prompt—this is normal.

  To install by hand instead, unzip the release into Applications, run
  `xattr -dr com.apple.quarantine /Applications/Ahed.app`, then open it.
- Follow setup to sign in and allow Accessibility, Input Monitoring and Screen Recording.
- Existing builds without updates need one manual installation of an update-enabled build.
- Later releases use signed downloads and ask before installation; there is no silent install.
- Verify the downloaded file using its release's SHA256SUMS.txt and read README-FIRST.txt.

A release marked as a controlled-test candidate is not a general rollout. Browser support and
permission continuity must be checked independently; a signed download alone does not prove them.

Each release provides Ahed's corresponding source and retains its AGPL-3.0 and third-party notices.
See the bundled COPYING, THIRD_PARTY_LICENSES.md and FORK.md for credits and licensing.

Product and policies: https://ahed.app/
Account: https://account.ahed.app/
Support: ahed.vibe@gmail.com
