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

  # Presentation stays separate from the install steps. Redirected output must
  # remain readable in logs; cursor control and colour are only for terminals.
  local interactive=false pending=false
  local green="" muted="" bold="" reset="" red=""
  local tick="OK" dot=".." arrow="->|"
  if [ -t 1 ] && [ -t 2 ] && [ "${TERM:-dumb}" != "dumb" ]; then
    interactive=true
    if [ -z "${NO_COLOR+x}" ]; then
      # Keep guidance in the terminal's normal foreground. Faint/dim text can
      # become unreadable on translucent themes and does not adapt to light ones.
      green=$'\033[32m'; bold=$'\033[1m'
      reset=$'\033[0m'; red=$'\033[31m'
    fi
  fi
  case "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" in
    *UTF-8*|*utf-8*|*UTF8*|*utf8*) tick="✓"; dot="·"; arrow="→|" ;;
  esac

  clear_status() {
    if [ "$pending" = true ]; then
      printf '\r\033[2K'
      pending=false
    fi
  }
  status() {
    clear_status
    if [ "$interactive" = true ]; then
      printf '  %s%s%s  %s' "$muted" "$dot" "$reset" "$*"
      pending=true
    else
      printf '  %s  %s\n' "$dot" "$*"
    fi
  }
  done_step() {
    clear_status
    printf '  %s%s%s  %s\n' "$green" "$tick" "$reset" "$*"
  }
  note() { printf '     %s%s%s\n' "$muted" "$*" "$reset"; }
  download_progress() {
    # curl supplies real transfer percentages separated by carriage returns.
    # Render only those values, keeping its hash bar and technical stderr out of
    # the UI. The enclosing pipefail still rejects any failed download. Unknown
    # transfer sizes retain the honest "Downloading" status without a fake %.
    local record="" percent="" previous=""
    local percentage_pattern='([0-9]{1,3}([.][0-9]+)?)%'
    while IFS= read -r -d $'\r' record || [ -n "$record" ]; do
      if [[ $record =~ $percentage_pattern ]]; then
        percent="${BASH_REMATCH[1]}"
        if [ "$percent" != "$previous" ]; then
          status "Downloading Ahed... $percent%"
          previous="$percent"
        fi
      fi
    done
    return 0
  }
  fail() {
    clear_status
    printf '\n  %s%sInstallation paused%s\n' "$red" "$bold" "$reset" >&2
    printf '  %s\n\n' "$*" >&2
    exit 1
  }

  local existing=false
  [ ! -e "$app" ] || existing=true
  printf '\n  %s%s ahed.%s\n' "$green$bold" "$arrow" "$reset"
  printf '  %sA little closer to your next idea.%s\n\n' "$muted" "$reset"

  # 1. Check the Mac
  [ "$(uname -s)" = "Darwin" ] || fail "This installer only runs on a Mac."
  [ "$(uname -m)" = "arm64" ] || fail "Ahed needs an Apple Silicon Mac (M1 or newer)."
  local major
  major="$(sw_vers -productVersion | cut -d. -f1)"
  [ "$major" -ge 14 ] || fail "Ahed needs macOS 14 Sonoma or newer. This Mac has $(sw_vers -productVersion)."

  # 2. Find the latest release (GitHub redirects /latest to /tag/<tag>)
  status "Finding the latest release..."
  local tag
  tag="${AHED_TAG:-}"
  if [ -z "$tag" ]; then
    tag="$(curl -fsSLI -o /dev/null -w '%{url_effective}' "$base/latest")" || fail "Could not reach GitHub. Check your internet connection."
    tag="${tag##*/}"
  fi
  case "$tag" in alpha-*) ;; *) fail "Unexpected release tag '$tag'." ;; esac
  local zip="Ahed-${tag#alpha-}.zip"
  local release="${tag#alpha-}"
  local version="${release%-*}" build="${release##*-}"
  # Private test builds can be ahead of the public feed. Re-running the public
  # installer must not silently replace a newer local repair with an old release.
  local installed_build="" installed_version=""
  if [ "$existing" = true ]; then
    installed_build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$app/Contents/Info.plist" 2>/dev/null || true)"
    if [[ "$installed_build" =~ ^[0-9]{1,9}$ ]] && [[ "$build" =~ ^[0-9]{1,9}$ ]] \
        && (( 10#$installed_build > 10#$build )); then
      installed_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist" 2>/dev/null || true)"
      done_step "Keeping Ahed ${installed_version:-installed} (build $installed_build)"
      note "Your installed version is newer than the public release."
      note "Nothing was downloaded or replaced."
      printf '\n'
      return 0
    fi
  fi
  if [ "$existing" = true ]; then
    done_step "Updating Ahed to $version (build $build)"
  else
    done_step "Installing Ahed $version (build $build)"
  fi

  # 3. Download and verify
  AHED_TMP="$(mktemp -d)"
  trap 'rm -rf "$AHED_TMP"' EXIT
  local tmp="$AHED_TMP"
  status "Downloading Ahed..."
  if [ "$interactive" = true ]; then
    curl -fL --progress-bar -o "$tmp/$zip" "$base/download/$tag/$zip" 2>&1 | download_progress || fail "Download interrupted. Check your connection and run the installer again."
  else
    curl -fsSL -o "$tmp/$zip" "$base/download/$tag/$zip" || fail "Download interrupted. Check your connection and run the installer again."
  fi
  status "Checking the download..."
  curl -fsSL -o "$tmp/SHA256SUMS.txt" "$base/download/$tag/SHA256SUMS.txt" || fail "Could not check the download. Please run the installer again."

  local expected actual
  expected="$(awk -v name="$zip" '$2 == name || $2 == "*" name { print $1; exit }' "$tmp/SHA256SUMS.txt")"
  [ -n "$expected" ] || fail "This release is missing its download checksum. Please contact ahed.vibe@gmail.com."
  [[ "$expected" =~ ^[[:xdigit:]]{64}$ ]] || fail "This release has an invalid download checksum. Please contact ahed.vibe@gmail.com."
  actual="$(shasum -a 256 "$tmp/$zip" | awk '{print $1}')"
  [ "$expected" = "$actual" ] || fail "Checksum mismatch, the download may be damaged. Please try again."
  done_step "Download verified"

  # 4. Unpack
  status "Preparing the app..."
  ditto -x -k "$tmp/$zip" "$tmp/unpacked" || fail "Could not unpack Ahed. Check that your Mac has enough free space, then try again."
  local new_app
  new_app="$(find "$tmp/unpacked" -maxdepth 2 -name 'Ahed.app' -type d | head -n1)"
  [ -n "$new_app" ] || fail "Ahed.app was not found inside $zip."
  [ -x "$new_app/Contents/MacOS/Ahed" ] || fail "The downloaded app is incomplete."

  # 5. Quit a running copy, then install
  if pgrep -x Ahed >/dev/null 2>&1; then
    status "Closing the previous Ahed..."
    osascript -e 'tell application "Ahed" to quit' >/dev/null 2>&1 || true
    local attempt
    for attempt in {1..10}; do
      pgrep -x Ahed >/dev/null 2>&1 || break
      sleep 1
    done
    if pgrep -x Ahed >/dev/null 2>&1; then
      fail "Ahed is still running. Quit it from its menu, then run the installer again."
    fi
    done_step "Closed the previous Ahed"
  fi

  local sudo=""
  if [ ! -w "$apps" ] || { [ -e "$app" ] && [ ! -w "$app" ]; }; then
    clear_status
    printf '\n'
    note "macOS needs your password to install in $apps."
    note "Nothing appears while you type. This is normal."
    printf '\n'
    sudo="sudo"
    sudo -v || fail "Authorization was cancelled. Your existing installation was not changed. Run the installer again when you are ready."
  fi
  status "Installing in $apps..."
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
  if [ "$existing" = true ]; then
    done_step "Ahed updated"
  else
    done_step "Ahed installed"
  fi
  status "Opening Ahed..."
  if ! open "$app"; then
    # Preserve both copies for manual recovery rather than deleting either one.
    fail "Ahed could not open. The new app is at $app; any previous copy is saved in $stage."
  fi
  $sudo rm -rf "$stage"
  done_step "Opened Ahed"
  printf '\n'
  if [ "$existing" = true ]; then
    note "Your account and settings are preserved."
    note "If setup is unfinished, continue in Ahed."
  else
    note "Your setup continues in the app."
    note "Sign in, then allow Accessibility, Input Monitoring"
    note "and Screen Recording when Ahed guides you."
  fi
  printf '\n'
}

main
