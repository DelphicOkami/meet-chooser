#!/bin/bash
# Dynamically discovers Chrome profiles and their signed-in accounts,
# presents a chooser dialog, then opens the Meet link as a PWA.

CHROME_DIR="$HOME/Library/Application Support/Google/Chrome"

# ── Load config (create with defaults on first run) ───────────────────────────

CONFIG_FILE="$HOME/.config/meet-chooser-config.sh"
if [ ! -f "$CONFIG_FILE" ]; then
    cat > "$CONFIG_FILE" <<'CONFIG'
# MeetChooser configuration
# Edit this file to customise behaviour. Changes take effect immediately.

# Email address for which Google Meet URL fragments will be stripped.
# This works around a bug where some accounts receive URLs with fragments
# that prevent the meeting from loading correctly.
# Set to "" to disable fragment stripping for all profiles.
STRIP_FRAGMENT_EMAIL=""

# Chrome PWA app ID for Google Meet.
PWA_APP_ID="kjgfgldnnfoeklkmfkjfagphfepbbdan"

# Path to the Google Chrome executable.
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
CONFIG
fi

# shellcheck source=/dev/null
source "$CONFIG_FILE"

# ── Discover profiles and their signed-in email addresses ─────────────────────

PROFILE_DIRS=()
PROFILE_EMAILS=()

while IFS= read -r -d '' prefs_file; do
    dir=$(basename "$(dirname "$prefs_file")")
    email=$(python3 -c "
import json, sys
try:
    p = json.load(open('$prefs_file'))
    infos = p.get('account_info', [])
    if infos:
        print(infos[0].get('email', ''))
    else:
        print('')
except:
    print('')
" 2>/dev/null)

    if [ -n "$email" ]; then
        PROFILE_DIRS+=("$dir")
        PROFILE_EMAILS+=("$email")
    fi
done < <(find "$CHROME_DIR" -maxdepth 2 -name "Preferences" -print0 2>/dev/null)

# ── Build dialog buttons ───────────────────────────────────────────────────────

if [ "${#PROFILE_EMAILS[@]}" -eq 0 ]; then
    osascript -e 'display alert "Meet Chooser" message "No signed-in Chrome profiles found."'
    exit 1
fi

URL="${@: -1}"

if [ "${#PROFILE_EMAILS[@]}" -eq 1 ]; then
    CHOICE="${PROFILE_EMAILS[0]}"
else
    BUTTONS=$(printf '"%s", ' "${PROFILE_EMAILS[@]}")
    BUTTONS="${BUTTONS%, }"

    CHOICE=$(osascript <<EOF
tell application "System Events" to activate
button returned of (display dialog "Open this Google Meet as which account?" ¬
  buttons {${BUTTONS}, "Cancel"} ¬
  default button 1 ¬
  cancel button "Cancel" ¬
  with title "Google Meet" ¬
  with icon note)
EOF
)
fi

# ── Resolve profile dir from chosen email ─────────────────────────────────────

PROFILE_DIR=""
for i in "${!PROFILE_EMAILS[@]}"; do
    if [ "${PROFILE_EMAILS[$i]}" = "$CHOICE" ]; then
        PROFILE_DIR="${PROFILE_DIRS[$i]}"
        break
    fi
done

if [ -z "$PROFILE_DIR" ]; then
    exit 0  # cancelled
fi

# ── Resolve URL ────────────────────────────────────────────────────────────────

if [ -n "$STRIP_FRAGMENT_EMAIL" ] && [ "$CHOICE" = "$STRIP_FRAGMENT_EMAIL" ]; then
    PATH_AND_QUERY=$(echo "$URL" | sed 's|https://meet.google.com||' | sed 's|#.*||')
    MEET_URL="https://meet.google.com${PATH_AND_QUERY}"
else
    MEET_URL="$URL"
fi

# ── Launch Chrome PWA ──────────────────────────────────────────────────────────

"$CHROME" \
    --profile-directory="$PROFILE_DIR" \
    --app-id="$PWA_APP_ID" \
    --app-launch-url-for-shortcuts-menu-item="$MEET_URL" \
    2>/dev/null &
disown $!
