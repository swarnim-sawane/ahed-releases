#!/bin/bash
# Ahed installer for Apple Silicon Macs (macOS 14+).
# Usage: curl -fsSL https://raw.githubusercontent.com/swarnim-sawane/ahed-releases/main/install.sh | bash
#
# What it does: finds the latest Ahed release on GitHub, downloads the ZIP,
# checks it against the release's SHA256SUMS.txt, puts Ahed.app in /Applications,
# removes the download quarantine flag and opens Ahed. It never re-signs the app.

set -euo pipefail

main() {
  local repo="swarnim-sawane/ahed-releases"
  local base="${AHED_BASE_URL:-https://github.com/$repo/releases}"
  local apps="${AHED_INSTALL_DIR:-/Applications}"
  local app="$apps/Ahed.app"

  step()  { printf '\033[1m==>\033[0m %s\n' "$*"; }
  fail() { printf '\033[31mError:\033[0m %s\n' "$*" >&2; exit 1; }

  # 1. Check the Mac
  [ "$(uname -s)" = "Darwin" ] || fail "This installer only runs on a Mac."
  [ "$(uname -m)" = "arm64" ] || fail "Ahed needs an Apple Silicon Mac (M1 or newer)."
  local major
  major="$(sw_vers -productVersion | cut -d. -f1)"
  [ "$major" -ge 14 ] || fail "Ahed needs macOS 14 Sonoma or newer. This Mac has $(sw_vers -productVersion)."

  # 2. Find the latest release (GitHub redirects /latest to /tag/<tag>)
  step "Finding the latest Ahed release..."
  local tag
  tag="${AHED_TAG:-}"
  if [ -z "$tag" ]; then
    tag="$(curl -fsSLI -o /dev/null -w '%{url_effective}' "$base/latest")" || fail "Could not reach GitHub. Check your internet connection."
    tag="${tag##*/}"
  fi
  case "$tag" in alpha-*) ;; *) fail "Unexpected release tag '$tag'." ;; esac
  local zip="Ahed-${tag#alpha-}.zip"
  step "Latest is $tag"

  # 3. Download and verify
  AHED_TMP="$(mktemp -d)"
  trap 'rm -rf "$AHED_TMP"' EXIT
  local tmp="$AHED_TMP"
  step "Downloading $zip..."
  curl -fL --progress-bar -o "$tmp/$zip" "$base/download/$tag/$zip" || fail "Download failed."
  curl -fsSL -o "$tmp/SHA256SUMS.txt" "$base/download/$tag/SHA256SUMS.txt" || fail "Could not download checksums."

  local expected actual
  expected="$(awk -v name="$zip" '$2 == name || $2 == "*" name { print $1; exit }' "$tmp/SHA256SUMS.txt")"
  [ -n "$expected" ] || fail "$zip is not listed in SHA256SUMS.txt."
  [[ "$expected" =~ ^[[:xdigit:]]{64}$ ]] || fail "The release checksum is invalid."
  actual="$(shasum -a 256 "$tmp/$zip" | awk '{print $1}')"
  [ "$expected" = "$actual" ] || fail "Checksum mismatch, the download may be damaged. Please try again."
  step "Checksum OK"

  # 4. Unpack
  ditto -x -k "$tmp/$zip" "$tmp/unpacked"
  local new_app
  new_app="$(find "$tmp/unpacked" -maxdepth 2 -name 'Ahed.app' -type d | head -n1)"
  [ -n "$new_app" ] || fail "Ahed.app was not found inside $zip."
  [ -x "$new_app/Contents/MacOS/Ahed" ] || fail "The downloaded app is incomplete."

  # 5. Quit a running copy, then install
  if pgrep -x Ahed >/dev/null 2>&1; then
    step "Quitting the running Ahed..."
    osascript -e 'tell application "Ahed" to quit' >/dev/null 2>&1 || true
    local attempt
    for attempt in {1..10}; do
      pgrep -x Ahed >/dev/null 2>&1 || break
      sleep 1
    done
    if pgrep -x Ahed >/dev/null 2>&1; then
      fail "Ahed is still running. Quit it from its menu, then run the installer again."
    fi
  fi

  local sudo=""
  if [ ! -w "$apps" ] || { [ -e "$app" ] && [ ! -w "$app" ]; }; then
    step "Your Mac password is needed to write to $apps."
    sudo="sudo"
  fi
  step "Installing to $app..."
  # Stage on the destination volume before touching the installed copy. Keep the
  # previous app until the new one has launched so a failed copy cannot erase it.
  local stage backup
  stage="$($sudo mktemp -d "$apps/.ahed-install.XXXXXX")" || fail "Could not prepare $apps."
  backup="$stage/previous.app"
  if ! $sudo ditto "$new_app" "$stage/Ahed.app"; then
    $sudo rm -rf "$stage"
    fail "Could not copy Ahed. Your existing installation was not changed."
  fi

  # 6. Remove the quarantine flag so Gatekeeper does not block first launch
  # These alpha releases are self-signed, not notarized. Only this verified
  # downloaded app has its quarantine flag removed; the app is never re-signed.
  if ! $sudo xattr -dr com.apple.quarantine "$stage/Ahed.app"; then
    $sudo rm -rf "$stage"
    fail "Could not prepare Ahed for launch. Your existing installation was not changed."
  fi
  if [ -e "$app" ]; then
    if ! $sudo mv "$app" "$backup"; then
      $sudo rm -rf "$stage"
      fail "Could not move the existing Ahed. Your installation was not changed."
    fi
  fi
  if ! $sudo mv "$stage/Ahed.app" "$app"; then
    if [ -e "$backup" ]; then
      $sudo mv "$backup" "$app" || fail "Installation failed. Your previous app is saved at $backup."
    fi
    $sudo rm -rf "$stage"
    fail "Installation failed. Any previous installation has been restored."
  fi

  # 7. Open
  step "Opening Ahed..."
  if ! open "$app"; then
    # Preserve both copies for manual recovery rather than deleting either one.
    fail "Ahed could not open. The new app is at $app; any previous copy is saved in $stage."
  fi
  $sudo rm -rf "$stage"
  echo
  step "Done. Follow Ahed's setup to allow Accessibility, Input Monitoring and Screen Recording."
}

main
