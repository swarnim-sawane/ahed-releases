# Install Ahed on your Mac

Your prompting sidekick. Complete a thought, improve a draft, and start writing with more context.

**Apple Silicon · macOS 14 or later · Invite-only alpha**

[Website](https://ahed.app/) · [Your account](https://account.ahed.app/) · [Get help](mailto:ahed.vibe@gmail.com)

## Before installing

Have your invited account ready. Ahed includes the hosted AI connection—you do not need an API key.
Downloading the app does not grant access by itself.

**Copy this command using the copy button in the top-right corner of the box:**

```bash
curl -fsSL https://raw.githubusercontent.com/swarnim-sawane/ahed-releases/main/install.sh | bash
```

## 1. Install Ahed

| Step | What to do |
| --- | --- |
| **Open Terminal** | Press **Command + Space**, type **Terminal**, then press **Return**. |
| **Run the command** | Paste the command above into Terminal, then press **Return**. |
| **Let it finish** | The installer downloads Ahed, checks its checksum, installs it in Applications and opens it. |

> [!TIP]
> **Asked for a password?** Enter your **Mac login password**, then press Return.
> No letters or dots appear while you type. This is normal.

The installer shows a compact download percentage. If Ahed is already installed, it updates the
app and preserves your account and settings. If you have a newer test build, it keeps that version
instead of replacing it with an older public release.

These alpha builds are self-signed and not notarized. The installer removes the downloaded app's
quarantine flag after checking its checksum; it never re-signs the app. You can
[read the installer](install.sh) before running it.

## 2. Connect your account

In Ahed, choose **Continue in browser** and sign in with your invited account using Google or email.
If your account was created with email and a password, continue using that method—Google does not
automatically merge it with another account.

Complete any browser **Open Ahed** confirmation to return to setup. Follow Ahed's connection
instructions rather than opening the account dashboard separately.

## 3. Allow the three permissions

Use the buttons in Ahed to open the relevant macOS settings. Enable **Ahed**, then return to setup.

| Permission | What it enables |
| --- | --- |
| **Accessibility** | Reads your draft and inserts suggestions you choose to accept. |
| **Input Monitoring** | Responds to typing and your acceptance shortcuts. |
| **Screen Recording** | Provides visual context around the composer to improve suggestions. |

If macOS asks you to quit and reopen Ahed, do so. Continue the same setup after it reopens.

Your draft and enabled relevant context may be processed online to provide suggestions.
Review the explanation in Ahed and the [privacy notice](https://ahed.app/privacy) before starting.

## 4. Try your first suggestion

1. Review the demo and context settings in Ahed.
2. Choose the app you want to use, then click **Start using Ahed** once.
3. In a supported composer, type a short draft and pause.
4. Accept a suggestion using the shortcut shown by Ahed. Review your message before sending it.

Your assigned access and allowance must be available before activation can complete. Signing in
alone does not start your access period. Ahed supplies the AI connection; paid billing is disabled
for this alpha. Complimentary access has no payment or automatic renewal.

## Need a hand?

| What happened? | What to do |
| --- | --- |
| **The download stopped** | Check your internet connection and run the command again. |
| **The connection link expired** | Start sign-in again from Ahed. Each connection attempt lasts 15 minutes. |
| **A permission still looks incomplete** | Check that Ahed is enabled in the matching macOS settings page, and relaunch if macOS asks. |
| **Signed in, but assistance is unavailable** | Check your account's invitation, activation and allowance. Shared-service limits can also pause assistance. |

Email **[ahed.vibe@gmail.com](mailto:ahed.vibe@gmail.com)** with a description or screenshot.
Never include a password, API key or verification link.

---

<details>
<summary><strong>Manual installation and future updates</strong></summary>

### Install manually

1. Open the [latest release](https://github.com/swarnim-sawane/ahed-releases/releases/latest).
2. Read **README-FIRST.txt** and **KNOWN_LIMITATIONS.md**. Download the app ZIP and **SHA256SUMS.txt**.
3. Check the ZIP's SHA-256 against its entry in **SHA256SUMS.txt** before opening it.
4. Extract the ZIP and put **Ahed.app** in Applications. Use the normal macOS **Open Anyway** flow
   if prompted. Alternatively, for this reviewed alpha, remove its quarantine flag in Terminal:

   ```bash
   xattr -dr com.apple.quarantine /Applications/Ahed.app
   ```

5. Open Ahed and follow setup. Do not re-sign the app or disable macOS protections globally.

### Keep Ahed up to date

Update-enabled installations can use **Check for Updates** in Ahed or **Settings → Help & updates**.
Update downloads are signed and installation asks for confirmation. macOS may ask for authorization.
An update preserves your settings and existing access period; it does not grant or renew access.
Older builds without updates need one manual installation of an update-enabled build.

The Terminal installer uses plain output when redirected. Set `NO_COLOR=1` to disable colour.

</details>

<details>
<summary><strong>Release status, source and licences</strong></summary>

This repository contains macOS release downloads, update-feed files, checksums and matching
corresponding source. Private development history and signing keys are not here.

Read the current release's **ONBOARDING_CHECKLIST.md** and **KNOWN_LIMITATIONS.md** for remaining
acceptance checks and supported integrations. Browser support and permission continuity must be
checked independently; a signed download alone does not prove them. A release marked as a
controlled-test candidate is not a general rollout.

Each release provides Ahed's corresponding source and retains its AGPL-3.0 and third-party notices.
See the bundled **COPYING**, **THIRD_PARTY_LICENSES.md** and **FORK.md** for credits and licensing.

</details>
