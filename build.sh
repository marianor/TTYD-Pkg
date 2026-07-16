#!/bin/sh

set -e

PKG_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="${PKG_DIR}/build"
OUTPUT_DIR="${BUILD_DIR}/output"
SDK_DIR="${BUILD_DIR}/sdk"
SDK_URL="https://downloadgb.asustor.com/developer/APKG_Utilities_2.0_0517.zip"
ARCH="${1:-x86-64}"
VERSION=$(grep '"version"' "${PKG_DIR}/control/config.json" | cut -d'"' -f4)
TMP_DIR="/tmp/apkg-build-$$"

echo "=== Building ttyd APKG ==="
echo "Architecture: ${ARCH}"

# --- Download Asustor SDK if not present ---
if [ ! -f "${SDK_DIR}/apkg-tools_py3.py" ]; then
    echo "Downloading Asustor SDK..."
    mkdir -p "${SDK_DIR}"
    curl -L -o "${SDK_DIR}/APKG_Utilities_2.0_0517.zip" "$SDK_URL"
    cd "$SDK_DIR"
    unzip -o APKG_Utilities_2.0_0517.zip
    rm -rf apkg-tools_py2.py APKG_Utilities_2.0_0517.zip
    chmod +x "${SDK_DIR}/apkg-tools_py3.py"
fi

# --- Download ttyd binary if not present ---
if [ ! -f "${BUILD_DIR}/bin/ttyd" ]; then
    echo "Downloading ttyd binary for ${ARCH}..."
    mkdir -p "${BUILD_DIR}/bin"
    TTYD_ARCH="${ARCH}"
    [ "$ARCH" = "x86-64" ] && TTYD_ARCH="x86_64"
    curl -L -o "${BUILD_DIR}/bin/ttyd" \
        "https://github.com/tsl0922/ttyd/releases/latest/download/ttyd.${TTYD_ARCH}"
    chmod +x "${BUILD_DIR}/bin/ttyd"

    echo "Verifying ttyd binary integrity..."
    EXPECTED_SHA=$(curl -sL \
        "https://github.com/tsl0922/ttyd/releases/latest/download/SHA256SUMS" \
        | grep "ttyd.${TTYD_ARCH}" | awk '{print $1}')
    ACTUAL_SHA=$(sha256sum "${BUILD_DIR}/bin/ttyd" | awk '{print $1}')
    if [ "$EXPECTED_SHA" != "$ACTUAL_SHA" ]; then
        echo "ERROR: ttyd binary checksum mismatch!"
        echo "  Expected: $EXPECTED_SHA"
        echo "  Actual:   $ACTUAL_SHA"
        exit 1
    fi
    echo "Checksum OK: $ACTUAL_SHA"
fi

# --- Prepare package layout ---
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR" "$OUTPUT_DIR"

echo "Preparing package layout..."
mkdir -p "$TMP_DIR/package/CONTROL" "$TMP_DIR/package/bin" "$TMP_DIR/package/etc" "$TMP_DIR/package/var"

cp "${PKG_DIR}/build/bin/ttyd" "$TMP_DIR/package/bin/ttyd"
chmod +x "$TMP_DIR/package/bin/ttyd"

cp "${PKG_DIR}/control/config.json" "$TMP_DIR/package/CONTROL/"
cp "${PKG_DIR}/control/description.txt" "$TMP_DIR/package/CONTROL/"
cp "${PKG_DIR}/control/icon.png" "$TMP_DIR/package/CONTROL/"
cp "${PKG_DIR}/control/post-install.sh" "$TMP_DIR/package/CONTROL/"
cp "${PKG_DIR}/control/post-uninstall.sh" "$TMP_DIR/package/CONTROL/"
cp "${PKG_DIR}/control/pre-install.sh" "$TMP_DIR/package/CONTROL/"
cp "${PKG_DIR}/control/pre-uninstall.sh" "$TMP_DIR/package/CONTROL/"
cp "${PKG_DIR}/control/start-stop.sh" "$TMP_DIR/package/CONTROL/"
cp "${PKG_DIR}/control/license.txt" "$TMP_DIR/package/CONTROL/"
cp "${PKG_DIR}/control/changelog.txt" "$TMP_DIR/package/CONTROL/"
cp "${PKG_DIR}/control/settings.conf" "$TMP_DIR/package/etc/"

# --- Create package using SDK ---
echo "Creating APKG package..."
python3 -c "
import os, sys
if os.geteuid() != 0:
    os.chown = lambda *a, **k: None
sys.argv = ['apkg-tools_py3.py', 'create', '${TMP_DIR}/package', '--destination', '${OUTPUT_DIR}']
exec(open('${SDK_DIR}/apkg-tools_py3.py').read())
"

# --- Cleanup ---
rm -rf "$TMP_DIR"

echo "=== Build complete ==="
ls -la "${OUTPUT_DIR}/"*.apk
