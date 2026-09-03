#!/bin/zsh
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
DIST_DIR="$ROOT_DIR/dist"
BUILD_ROOT="$ROOT_DIR/.build/release-universal"
VERSION="${VERSION:-0.1.0-beta.1}"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
X86_TRIPLE="x86_64-apple-macosx13.0"
ARM_TRIPLE="arm64-apple-macosx13.0"
X86_BUILD="$BUILD_ROOT/x86_64"
ARM_BUILD="$BUILD_ROOT/arm64"

cd "$ROOT_DIR"
swift build -c release --triple "$X86_TRIPLE" --scratch-path "$X86_BUILD"
swift build -c release --triple "$ARM_TRIPLE" --scratch-path "$ARM_BUILD"
swift test -c release --triple "$X86_TRIPLE" --scratch-path "$X86_BUILD"

X86_BIN=$(swift build -c release --triple "$X86_TRIPLE" --scratch-path "$X86_BUILD" --show-bin-path)
ARM_BIN=$(swift build -c release --triple "$ARM_TRIPLE" --scratch-path "$ARM_BUILD" --show-bin-path)
RESOURCE_BUNDLE=$(find "$X86_BIN" -maxdepth 1 -type d -name 'TouchDSH_TouchDSHShared.bundle' -print -quit)
[[ -n "$RESOURCE_BUNDLE" ]] || { echo "Shared resource bundle not found" >&2; exit 1; }

mkdir -p "$DIST_DIR"

package_app() {
    local app_name="$1"
    local executable="$2"
    local plist="$3"
    local archive_name="$4"
    local app_dir="$DIST_DIR/$app_name.app"

    rm -rf "$app_dir"
    mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
    lipo -create "$X86_BIN/$executable" "$ARM_BIN/$executable" -output "$app_dir/Contents/MacOS/$executable"
    cp "$plist" "$app_dir/Contents/Info.plist"
    cp "$ROOT_DIR/Packaging/TouchDSH.icns" "$app_dir/Contents/Resources/TouchDSH.icns"
    ditto "$RESOURCE_BUNDLE" "$app_dir/Contents/Resources/$(basename "$RESOURCE_BUNDLE")"

    if ! "$app_dir/Contents/MacOS/$executable" --self-test-resources; then
        echo "Resource self-test failed for $app_name" >&2
        exit 1
    fi

    if [[ "$SIGN_IDENTITY" == "-" ]]; then
        codesign --force --options runtime --timestamp=none --sign - "$app_dir"
    else
        codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$app_dir"
    fi
    codesign --verify --deep --strict --verbose=2 "$app_dir"
    rm -f "$DIST_DIR/$archive_name"
    ditto -c -k --keepParent "$app_dir" "$DIST_DIR/$archive_name"
}

package_app "Touch DSH" "TouchDSHTouchBar" "$ROOT_DIR/Packaging/TouchBar/Info.plist" "Touch-DSH-TouchBar-$VERSION.zip"
package_app "Touch DSH Menu" "TouchDSHMenu" "$ROOT_DIR/Packaging/Menu/Info.plist" "Touch-DSH-Menu-$VERSION.zip"

cd "$DIST_DIR"
shasum -a 256 "Touch-DSH-TouchBar-$VERSION.zip" "Touch-DSH-Menu-$VERSION.zip" > SHA256SUMS.txt
echo "$DIST_DIR"
