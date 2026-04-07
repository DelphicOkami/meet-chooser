# MeetChooser

A macOS Automator app that intercepts Google Meet links and lets you choose which Chrome profile to open them with. Useful when you have multiple Google accounts (e.g. personal and work) and want meetings to open in the right account's PWA rather than whichever Chrome profile happened to be in the foreground.

## How it works

When a Google Meet URL is opened, MeetChooser presents a dialog listing all signed-in Chrome profiles by email address. Pick an account and the meeting opens as a PWA in that profile. If only one profile is signed in, the dialog is skipped entirely.

## Prerequisites

- macOS
- Google Chrome installed at `/Applications/Google Chrome.app`
- The Google Meet PWA installed in at least one Chrome profile (see [Installing the Meet PWA](#installing-the-meet-pwa))
- A URL routing tool to intercept Meet links — see [URL handler setup](#url-handler-setup)

## Installation

1. Download the latest `MeetChooser.app.zip` from [GitHub Releases](https://github.com/DelphicOkami/meet-chooser/releases/latest)
2. Unzip and copy `MeetChooser.app` to `~/Applications` (or `/Applications`)
3. Strip macOS extended attributes and apply an ad-hoc signature to allow launch:
   ```bash
   xattr -cr ~/Applications/MeetChooser.app
   codesign --force --deep --sign - ~/Applications/MeetChooser.app
   ```
4. On first run, a config file will be created automatically at:
   ```
   ~/.config/meet-chooser-config.ini
   ```
5. Edit that file to customise behaviour — see [Configuration](#configuration)

## Configuration

On first run, MeetChooser creates `~/.config/meet-chooser-config.ini` with defaults. You can also copy the included example file as a starting point:

```bash
cp meet-chooser-config.example.ini ~/.config/meet-chooser-config.ini
```

The config file uses INI format with a `[meet-chooser]` section. Available options:

| Variable | Default | Description |
|----------|---------|-------------|
| `STRIP_FRAGMENT_EMAIL` | `""` | Email address for which URL fragments are stripped before opening. Workaround for a bug where fragment-bearing URLs prevent meetings from loading. Leave empty to disable. |
| `PWA_APP_ID` | `kjgfgldnnfoeklkmfkjfagphfepbbdan` | Chrome PWA app ID for Google Meet. The default is correct for most users — see [Finding the Meet PWA app ID](#finding-the-meet-pwa-app-id) if you need to verify. |
| `CHROME` | `/Applications/Google Chrome.app/Contents/MacOS/Google Chrome` | Full path to the Chrome executable. Change if Chrome is installed elsewhere. |

Changes take effect immediately — no need to restart anything.

## macOS permissions

### Screen recording

When you try to share your screen in a Google Meet, macOS may prompt you to grant screen recording permission to MeetChooser rather than Chrome. This happens because MeetChooser launched the PWA, making it the parent process in macOS's view.

To fix this, grant screen recording permission to MeetChooser:

1. Open **System Settings → Privacy & Security → Screen Recording**
2. If MeetChooser is listed, enable the toggle next to it
3. If it is not listed, click **+**, navigate to `~/Applications` (or `/Applications`), and add `MeetChooser.app`

You may need to restart Chrome after granting the permission for it to take effect.

## URL handler setup

MeetChooser needs to be registered as the handler for Google Meet URLs. The recommended approach is [Finicky](https://github.com/johnste/finicky), a free macOS app that acts as a default browser proxy and routes URLs to different apps based on rules.

1. Install Finicky and set it as your default browser
2. Add a rule to your `~/.finicky.js` config to send Meet URLs to MeetChooser:

```js
export default {
  defaultBrowser: {
    name: "com.google.Chrome",
    appType: "bundleId",
  },
  handlers: [
    {
      match: finicky.matchHostnames(["meet.google.com"]),
      browser: {
        name: "/Applications/MeetChooser.app",
        appType: "path",
      },
    },
  ],
};
```

Finicky will then pass matching URLs to MeetChooser via Apple Events, which triggers the profile chooser dialog.

## Installing the Meet PWA

The Meet PWA must be installed in each Chrome profile you want to use:

1. Open Chrome with the profile you want
2. Go to [meet.google.com](https://meet.google.com)
3. Click the install icon (⊕) in the address bar, or go to **⋮ menu → Cast, save, and share → Install page as app**

## Finding the Meet PWA app ID

The `PWA_APP_ID` in the config file identifies the Meet PWA to Chrome. It is normally the same for everyone (`kjgfgldnnfoeklkmfkjfagphfepbbdan`) but you can verify or look it up if needed.

**Via the filesystem (easiest):**

1. Open Finder and navigate to `~/Applications/Chrome Apps.localized/`
2. Find `Google Meet.app`, right-click → **Show Package Contents**
3. Open `Contents/Info.plist`
4. Look for the `CrAppModeShortcutID` key — its value is the app ID

**Via the terminal:**

```bash
defaults read ~/Applications/Chrome\ Apps.localized/Google\ Meet.app/Contents/Info.plist CrAppModeShortcutID
```

**Via Chrome:**

1. Open Chrome and go to `chrome://apps`
2. Right-click **Google Meet** → **Details**
3. The app ID appears in the address bar: `chrome://apps/detail/<APP_ID>`

## Development

The meaningful source files are:

| File | Purpose |
|------|---------|
| `MeetChooser.app/Contents/Resources/Scripts/meet-chooser.sh` | Main logic — edit this directly |
| `applet.applescript` | AppleScript source — edit this for changes to the applet |

The compiled `main.scpt` inside the bundle is a binary derived from `applet.applescript`. After editing the AppleScript source, recompile and commit both:

```bash
osacompile -o MeetChooser.app/Contents/Resources/Scripts/main.scpt applet.applescript
git add applet.applescript MeetChooser.app/Contents/Resources/Scripts/main.scpt
git commit
```

When copying the app to a new machine, strip macOS extended attributes and apply an ad-hoc signature to avoid Gatekeeper blocking the launch:

```bash
xattr -cr MeetChooser.app
codesign --force --deep --sign - MeetChooser.app
```
