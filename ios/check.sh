#!/bin/bash
# Compile the runtime for iOS (and its Objective-C backends for macOS, to
# keep the Mac build whole) WITHOUT the game: no gen/ needed, nothing linked.
# What it catches is every compile error in runtime/ on either platform; the
# lifted game and the link are ios/build.sh's (with your SPEED2.EXE).
# Runs on a Mac with Xcode, and in GitHub Actions (.github/workflows/ios-check.yml).
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; cd "$ROOT"
MINIOS="${MINIOS:-17.0}"
OUT="$(mktemp -d)"; trap 'rm -rf "$OUT"' EXIT
IOS="-target arm64-apple-ios$MINIOS -isysroot $(xcrun --sdk iphoneos --show-sdk-path)"
MAC="-target arm64-apple-macos11.0 -isysroot $(xcrun --sdk macosx --show-sdk-path)"
CC="$(xcrun --find clang)"
eval "$(grep -E '^CSRC=' link.sh)"
# module.c includes the lifted game's headers (gen/), the only runtime file that does
JOBS=()
for f in $CSRC; do [ "$f" = module ] || JOBS+=("ios runtime/$f.c"); done
for f in metal audio bundle gamepad keyboard_ios fpscounter texrep ios_app; do JOBS+=("ios runtime/$f.m"); done
JOBS+=("ios ios/main.m")
for f in metal audio bundle gamepad keyboard_mac fpscounter texrep; do JOBS+=("mac runtime/$f.m"); done
export CC IOS MAC OUT
printf '%s\n' "${JOBS[@]}" | xargs -P "$(sysctl -n hw.ncpu)" -L 1 sh -c '
  case "$0" in ios) T="$IOS" ;; *) T="$MAC" ;; esac
  case "$1" in *.m) X="-fobjc-arc" ;; *) X="" ;; esac
  o="$OUT/$0_$(echo "$1" | tr / _).o"
  if "$CC" $T -O1 $X -DNFS_ENHANCED=0 -Iruntime -c -o "$o" "$1" 2> "$o.err"; then
    w=$(grep -c "warning:" "$o.err" || true); echo "ok    $0  $1${w:+  ($w warnings)}" | sed "s/  (0 warnings)//"
  else echo "FAIL  $0  $1"; grep -E "error:" -A3 "$o.err" | head -40; exit 1; fi'
echo "all of runtime/ compiles for iOS $MINIOS (and the Objective-C backends for macOS)"
