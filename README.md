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

1. Copy `MeetChooser.app` to `~/Applications` (or `/Applications`)
2. Right-click → **Open** on first launch to bypass Gatekeeper
3. On first run, a config file will be created automatically at:
   ```
   ~/.config/meet-chooser-config.sh
   ```
4. Edit that file to customise behaviour — see [Configuration](#configuration)

## Configuration

The config file is created with defaults on first run:

```bash
# ~/.config/meet-chooser-config.sh

# Email address for which Google Meet URL fragments will be stripped.
# This works around a bug where some accounts receive URLs with fragments
# that prevent the meeting from loading correctly.
# Set to "" to disable fragment stripping for all profiles.
STRIP_FRAGMENT_EMAIL=""

# Chrome PWA app ID for Google Meet.
PWA_APP_ID="kjgfgldnnfoeklkmfkjfagphfepbbdan"

# Path to the Google Chrome executable.
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
```

Changes take effect immediately — no need to restart anything.

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

When copying the app to a new machine, strip macOS extended attributes first to avoid Gatekeeper noise:

```bash
xattr -cr MeetChooser.app
```
