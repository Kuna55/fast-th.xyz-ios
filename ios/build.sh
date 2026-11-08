#!/bin/bash
# Build the iOS port's code into out/ios/ (objects + nfsu2.filelist, which the
# app links): the lifted game (gen/all, gen/server, from ./gen.sh with your
# own SPEED2.EXE) and the runtime, for arm64 iPhones and iPads.  The Xcode
# project (ios/project.yml) runs this before it links, so a build in Xcode
# is enough; run it by hand to see the compile output on its own.
#
#   ios/build.sh                 build what changed
#   FULL=1 ios/build.sh          rebuild everything
#   MINIOS=18.0 ios/build.sh     another deployment target (default 17.0)
#
# The same lists as build.sh + link.sh (the Mac build), with the iOS
# backends: keyboard_ios.m for keyboard_mac.m, ios_app.m (the app and scene
# delegates), tests/boot.c's main renamed nfsu2_main (iOS owns main()).
set -e     # no pipefail: "ls shard_*.c fntab.c stubs.c" is fine without a stubs.c
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; cd "$ROOT"

[ -f gen/all/fntab.c ] || { echo "gen/all missing: run ./gen.sh <path to SPEED2.EXE> first (see ios/README.md)"; exit 1; }
[ -f gen/server/fntab.c ] || { echo "gen/server missing: run ./gen.sh <path to SPEED2.EXE> first"; exit 1; }
web/tools/gencheck.sh

MINIOS="${MINIOS:-17.0}"
SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
CC="$(xcrun --sdk iphoneos --find clang)"
# apple-a14: the oldest chip iOS 17+ supports well enough for this game (A12
# runs iOS 17 too, but the lifted code is tuned for big cores); -mcpu only
# picks instructions every A14 and later has.
MCPU="${MCPU:-apple-a14}"
OPT="${OPT:--O3 -mcpu=$MCPU}"
TGT="-target arm64-apple-ios$MINOS -isysroot $SDK"
J="${J:-$(sysctl -n hw.ncpu)}"
OUT="$ROOT/out/ios"
mkdir -p "$OUT/obj" "$OUT/obj/srv"
rm -rf "$OUT/rt"; mkdir -p "$OUT/rt"          # the runtime is rebuilt every time (a minute at most)

# ---- the lifted shards (as build.sh: one compile per changed shard) -------
export CC OPT TGT OUT FULL
export HDRSUM="$(cat runtime/cpu.h runtime/splitscreen_mem.h | shasum | cut -c1-16)"
{ (cd gen/all && ls shard_*.c fntab.c stubs.c 2>/dev/null | sed "s|^|all |")
  (cd gen/server && ls shard_*.c fntab.c stubs.c 2>/dev/null | sed "s|^|server |"); } | \
  xargs -P "$J" -n 2 sh -c '
    case "$1" in all) od="$OUT/obj" ;; *) od="$OUT/obj/srv" ;; esac
    cd "$0/gen/$1"; shift
    obj="$od/$(basename "$1" .c).o"
    sum=$( (cat "$1" decls.h; echo "$OPT $TGT $HDRSUM") | shasum | cut -c1-40)
    if [ -z "$FULL" ] && [ -f "$obj" ] && [ "$(cat "$obj.sum" 2>/dev/null)" = "$sum" ]; then exit 0; fi
    o=$("$CC" $TGT $OPT -c -I"$0/runtime" -I. -Wno-unused-label -Wno-parentheses-equality \
          -o "$obj" "$1" 2>&1); r=$?
    [ -z "$o" ] || printf "%s\n" "$o" | head -5
    [ $r -eq 0 ] || echo "DID NOT COMPILE: gen/$(basename "$PWD")/$1" >&2
    [ $r -eq 0 ] && echo "$sum" > "$obj.sum" && echo "  compiled: $(basename "$PWD")/$1"
    exit $r' "$ROOT"

# ---- the runtime (link.sh's lists) ------------------------------------------
eval "$(grep -E '^CSRC=' link.sh)"
MSRC="metal audio bundle gamepad keyboard_ios fpscounter texrep ios_app"
CF="$TGT $OPT -DNFS_ENHANCED=0 -Iruntime -Igen/all"
pids=""
for f in $CSRC; do
  [ -f "runtime/$f.c" ] || { echo "runtime/$f.c missing (link.sh lists it)"; exit 1; }
  fx=""; case "$f" in roam_core|roam_game) fx="-ffp-contract=off" ;; esac
  "$CC" $CF $fx -c -o "$OUT/rt/$f.o" "runtime/$f.c" & pids="$pids $!"
done
for f in $MSRC; do
  "$CC" $CF -fobjc-arc -c -o "$OUT/rt/$f.o" "runtime/$f.m" & pids="$pids $!"
done
"$CC" $TGT $OPT -Iruntime -Igen/all -c -o "$OUT/rt/impargs.o" gen/all/impargs.c & pids="$pids $!"
"$CC" $TGT $OPT -Iruntime -c -o "$OUT/rt/srv_impargs.o" gen/server/impargs.c & pids="$pids $!"
"$CC" $TGT $OPT -Iruntime -c -o "$OUT/rt/srv_modinfo.o" gen/server/modinfo.c & pids="$pids $!"
"$CC" $CF -Dmain=nfsu2_main -c -o "$OUT/rt/boot.o" tests/boot.c & pids="$pids $!"
fail=0
for p in $pids; do wait "$p" || fail=1; done
[ $fail -eq 0 ] || { echo "runtime: compile error (above)"; exit 1; }

# ---- the object list the app links (-filelist, every object, as the Mac
# links them: no archive, whose member names would collide between gen/all's
# and gen/server's shard_NNN.o, and weak defaults never win over the real
# definitions).  Only this lift's shards: an older lift's extra ones stay out.
{ (cd gen/all && ls shard_*.c fntab.c stubs.c 2>/dev/null | sed "s|\.c\$|.o|; s|^|$OUT/obj/|")
  (cd gen/server && ls shard_*.c fntab.c stubs.c 2>/dev/null | sed "s|\.c\$|.o|; s|^|$OUT/obj/srv/|")
  ls "$OUT"/rt/*.o; } > "$OUT/nfsu2.filelist"
echo "ios: $(wc -l < "$OUT/nfsu2.filelist" | tr -d ' ') objects in $OUT/nfsu2.filelist, iOS $MINIOS, $MCPU"
