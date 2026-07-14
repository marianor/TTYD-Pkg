#!/bin/sh

PKG_DIR="/usr/local/AppCentral/ttyd"
SETTINGS_FILE="${PKG_DIR}/settings.json"
TEMPLATE_FILE="${PKG_DIR}/index.html.in"
HTML_FILE="${PKG_DIR}/index.html"

DEFAULT_FG="#d4d4d4"
DEFAULT_BG="#1e1e1e"
DEFAULT_FONT_SIZE="14"
DEFAULT_FONT_FAMILY="monospace"

FG="$DEFAULT_FG"
BG="$DEFAULT_BG"
FONT_SIZE="$DEFAULT_FONT_SIZE"
FONT_FAMILY="$DEFAULT_FONT_FAMILY"

if [ -f "$SETTINGS_FILE" ]; then
    FG=$(sed -n 's/.*"fg"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$SETTINGS_FILE")
    BG=$(sed -n 's/.*"bg"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$SETTINGS_FILE")
    FONT_SIZE=$(sed -n 's/.*"fontSize"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p' "$SETTINGS_FILE")
    FONT_FAMILY=$(sed -n 's/.*"fontFamily"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$SETTINGS_FILE")
fi

[ -z "$FG" ] && FG="$DEFAULT_FG"
[ -z "$BG" ] && BG="$DEFAULT_BG"
[ -z "$FONT_SIZE" ] && FONT_SIZE="$DEFAULT_FONT_SIZE"
[ -z "$FONT_FAMILY" ] && FONT_FAMILY="$DEFAULT_FONT_FAMILY"

sed -e "s/__FG__/${FG}/g" \
    -e "s/__BG__/${BG}/g" \
    -e "s/__FONT_SIZE__/${FONT_SIZE}/g" \
    -e "s/__FONT_FAMILY__/${FONT_FAMILY}/g" \
    "$TEMPLATE_FILE" > "$HTML_FILE"
