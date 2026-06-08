#!/usr/bin/env bash
# Icon generation pipeline for VaultVerse.
# Surfaces: menu bar (22/44 px, no inset), bundle .icns (0.82 inset),
#           dock/runtime (512 px, 0.72 inset).
# Usage: bash scripts/generate-icons.sh [/path/to/master.png]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

MASTER="${1:-$REPO_ROOT/vault-verse.png}"
APPICONSET="$REPO_ROOT/App/Resources/Assets.xcassets/AppIcon.appiconset"
ICONS_DIR="$REPO_ROOT/App/Resources/Icons"
# Keep the transient .iconset outside App/ so Xcode doesn't bundle it, but write
# the finished AppIcon.icns into App/Resources for Finder/Spotlight/Launchpad.
ICONSET_DIR="$REPO_ROOT/scripts/AppIcon.iconset"
ICNS_OUT="$ICONS_DIR/AppIcon.icns"

# Inset ratios — change ONLY these to retune each surface.
BUNDLE_RATIO=0.82
DOCK_RATIO=0.72

# Exact target sizes from the native-surface spec.
BUNDLE_SIZES=(16 32 64 128 256 512 1024)
BUNDLE_TARGETS=(13 26 52 105 210 420 840)
DOCK_SIZE=512
DOCK_TARGET=369

# ── helpers ──────────────────────────────────────────────────────────────────

die() { printf "ERROR: %s\n" "$*" >&2; exit 1; }
step() { printf "\n→ %s\n" "$*"; }
ok()   { printf "  %s\n" "$*"; }
require_file() { [[ -f "$1" ]] || die "Required file missing: $1"; }

check_master() {
    [[ -f "$MASTER" ]] || die "Master icon not found: $MASTER"
    local W H
    W=$(sips --getProperty pixelWidth  "$MASTER" | awk '/pixelWidth/{print $2}')
    H=$(sips --getProperty pixelHeight "$MASTER" | awk '/pixelHeight/{print $2}')
    [[ "$W" -ge 1024 ]] || die "Master width must be ≥1024 px (got ${W})"
    [[ "$W" -eq "$H" ]] || die "Master must be square (got ${W}×${H})"
    printf "✓ Master: %s×%s px\n" "$W" "$H"
}

# Plain downscale — no inset (used for menu bar).
downscale() {
    local IN="$1" OUT="$2" S="$3"
    sips -z "$S" "$S" "$IN" --out "$OUT" > /dev/null
}

# Inset = shrink to an exact target size, then re-pad to S×S with a transparent
# border. Targets are intentionally hard-coded so the native surface math stays
# pixel-for-pixel identical to the spec.
inset() {
    local IN="$1" OUT="$2" S="$3" TARGET="$4"
    local TMP
    TMP="$(mktemp /tmp/vv_icon_XXXXXX.png)"
    sips -z "$TARGET" "$TARGET" "$IN" --out "$TMP" > /dev/null
    sips -p "$S" "$S"  "$TMP"   --out "$OUT" > /dev/null
    rm -f "$TMP"
}

assert_png_size() {
    local FILE="$1" EXPECTED="$2"
    require_file "$FILE"
    local W H
    W=$(sips --getProperty pixelWidth  "$FILE" | awk '/pixelWidth/{print $2}')
    H=$(sips --getProperty pixelHeight "$FILE" | awk '/pixelHeight/{print $2}')
    [[ "$W" == "$EXPECTED" && "$H" == "$EXPECTED" ]] \
        || die "Unexpected size for $FILE (got ${W}×${H}, expected ${EXPECTED}×${EXPECTED})"
}

build_icns_fallback() {
    local ICONSET="$1" OUT="$2"
    python3 - "$ICONSET" "$OUT" <<'PY'
from pathlib import Path
import struct
import sys

iconset = Path(sys.argv[1])
out = Path(sys.argv[2])

entries = [
    ("icp4", "icon_16x16.png"),
    ("ic11", "icon_16x16@2x.png"),
    ("icp5", "icon_32x32.png"),
    ("ic12", "icon_32x32@2x.png"),
    ("ic07", "icon_128x128.png"),
    ("ic13", "icon_128x128@2x.png"),
    ("ic08", "icon_256x256.png"),
    ("ic14", "icon_256x256@2x.png"),
    ("ic09", "icon_512x512.png"),
    ("ic10", "icon_512x512@2x.png"),
]

chunks = []
for code, name in entries:
    data = (iconset / name).read_bytes()
    chunks.append(code.encode("ascii") + struct.pack(">I", len(data) + 8) + data)

body = b"".join(chunks)
out.write_bytes(b"icns" + struct.pack(">I", len(body) + 8) + body)
PY
}

# ── setup ─────────────────────────────────────────────────────────────────────

mkdir -p "$ICONS_DIR" "$ICONSET_DIR" "$APPICONSET"
check_master

# ── Surface 1: menu bar (plain downscale, no inset) ──────────────────────────

step "Menu bar icons (22 px 1×, 44 px 2×)"
downscale "$MASTER" "$ICONS_DIR/menubar.png"    22
downscale "$MASTER" "$ICONS_DIR/menubar@2x.png" 44
assert_png_size "$ICONS_DIR/menubar.png" 22
assert_png_size "$ICONS_DIR/menubar@2x.png" 44
ok "menubar.png    22×22"
ok "menubar@2x.png 44×44"

# ── Surface 2: bundle .icns (0.82 inset) ─────────────────────────────────────

step "Bundle icon sizes (inset ratio $BUNDLE_RATIO)"
for IDX in "${!BUNDLE_SIZES[@]}"; do
    S="${BUNDLE_SIZES[$IDX]}"
    TARGET="${BUNDLE_TARGETS[$IDX]}"
    inset "$MASTER" "$ICONS_DIR/icon_${S}.png" "$S" "$TARGET"
    assert_png_size "$ICONS_DIR/icon_${S}.png" "$S"
    ok "icon_${S}.png"
done

step "Assembling .iconset"
cp "$ICONS_DIR/icon_16.png"   "$ICONSET_DIR/icon_16x16.png"
cp "$ICONS_DIR/icon_32.png"   "$ICONSET_DIR/icon_16x16@2x.png"
cp "$ICONS_DIR/icon_32.png"   "$ICONSET_DIR/icon_32x32.png"
cp "$ICONS_DIR/icon_64.png"   "$ICONSET_DIR/icon_32x32@2x.png"
cp "$ICONS_DIR/icon_128.png"  "$ICONSET_DIR/icon_128x128.png"
cp "$ICONS_DIR/icon_256.png"  "$ICONSET_DIR/icon_128x128@2x.png"
cp "$ICONS_DIR/icon_256.png"  "$ICONSET_DIR/icon_256x256.png"
cp "$ICONS_DIR/icon_512.png"  "$ICONSET_DIR/icon_256x256@2x.png"
cp "$ICONS_DIR/icon_512.png"  "$ICONSET_DIR/icon_512x512.png"
cp "$ICONS_DIR/icon_1024.png" "$ICONSET_DIR/icon_512x512@2x.png"

step "Copying exact filenames to AppIcon.appiconset"
for FILE in \
    icon_16x16.png icon_16x16@2x.png icon_32x32.png icon_32x32@2x.png \
    icon_128x128.png icon_128x128@2x.png icon_256x256.png icon_256x256@2x.png \
    icon_512x512.png icon_512x512@2x.png
do
    require_file "$ICONSET_DIR/$FILE"
    cp "$ICONSET_DIR/$FILE" "$APPICONSET/$FILE"
done
ok "10 slots populated"

step "iconutil → AppIcon.icns"
if ! iconutil -c icns -o "$ICNS_OUT" "$ICONSET_DIR"; then
    step "iconutil rejected this iconset on macOS 26.5; writing PNG-backed .icns fallback"
    build_icns_fallback "$ICONSET_DIR" "$ICNS_OUT"
fi
require_file "$ICNS_OUT"
ok "AppIcon.icns → App/Resources/Icons/"
ok "10 PNG files → $APPICONSET"

# ── Surface 3: dock / runtime (0.72 inset, 512 px canvas) ────────────────────

step "Dock / runtime icon (inset ratio $DOCK_RATIO, 512 px)"
inset "$MASTER" "$ICONS_DIR/AppIconRuntime.png" "$DOCK_SIZE" "$DOCK_TARGET"
assert_png_size "$ICONS_DIR/AppIconRuntime.png" "$DOCK_SIZE"
ok "AppIconRuntime.png  512×512"

# ── Validate Info.plist ───────────────────────────────────────────────────────

step "Validating Info.plist"
plutil -lint "$REPO_ROOT/App/Resources/Info.plist" && ok "Info.plist OK"

# ── Summary ───────────────────────────────────────────────────────────────────

printf "\n✅ Icon pipeline complete.\n"
printf "   [✓] Menu bar      menubar.png (22 px 1×) + menubar@2x.png (44 px 2×)\n"
printf "   [✓] Bundle .icns  AppIcon.icns  (7 inset sizes, ratio %.2f)\n" "$BUNDLE_RATIO"
printf "   [✓] Appiconset    AppIcon.appiconset (10 Xcode slots)\n"
printf "   [✓] Dock/runtime  AppIconRuntime.png (512 px, ratio %.2f)\n" "$DOCK_RATIO"
printf "\nNext: xcodegen generate && open VaultVerse.xcodeproj\n"
