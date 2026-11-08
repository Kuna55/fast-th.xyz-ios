# NFSU2 on iPhone and iPad (native)

This is an iOS build of [th0mk/nfsu2-web](https://github.com/th0mk/nfsu2-web)'s native macOS port. The game's x86 code is
translated to C ahead of time (`./gen.sh`), compiled for arm64 iOS and drawn with Metal. There is no browser and no
emulation at run time. It is the Mac app's renderer, sound and game code, with an iOS shell: a window, touch, an
on-screen controller, the audio session and the Files app for the game folder.

> **Status: untested.** This port was written without a Mac, so nobody has compiled or run it yet. Expect the first
> build to need fixes. The parts that most likely need attention are listed under [If it does not work](#if-it-does-not-work).

As with the Mac app, you bring your own game. The build is made from your own `SPEED2.EXE`, so neither the build nor
the app can be shared with anyone. Nothing made from the game is ever committed (`gen/` and `out/` are ignored).

## What you need

- **A Mac** with Xcode (16 or newer) and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).
- **Python 3** for the lifter (`requirements.txt`).
- **Your game:** the PC version patched to v1.2 (North America), with this exact `SPEED2.EXE`: 4,800,512 bytes,
  SHA-256 `f9dd86c054878ce6276beb07c1fd61874f7a1e4bf1f241b084c65b73e24168a7`.
- **An iPhone or iPad with iOS 17 or later.** An A15 chip or newer is the realistic minimum for smooth races.
  M-chip iPads are the best fit.
- **A paid Apple Developer account (most likely).** The game reserves a 4 GB address space plus a 1 GB thread stack,
  and needs more memory than iOS allows an app by default. The app therefore asks for the *Extended Virtual Addressing*
  and *Increased Memory Limit* entitlements (`ios/NFSU2.entitlements`). A free Apple ID may not be able to sign
  those. See below if signing fails.

## Build and install

```sh
# 1. the lifter, then translate your SPEED2.EXE to C (gen/, a few minutes)
python3 -m venv .venv && .venv/bin/pip install -r requirements.txt
./gen.sh "/path/to/Need for Speed Underground 2/SPEED2.EXE"

# 2. your signing settings (team ID: Xcode > Settings > Accounts, or developer.apple.com > Membership)
cat > ios/local.xcconfig <<'EOF'
DEVELOPMENT_TEAM = ABCDE12345
PRODUCT_BUNDLE_IDENTIFIER = com.yourname.nfsu2
EOF

# 3. the Xcode project
cd ios && xcodegen && open NFSU2.xcodeproj
```

In Xcode, pick your iPhone as the destination and press **Run**. The first build compiles the whole translated game
(`ios/build.sh` runs as a build phase), which takes several minutes. Later builds only compile what changed.

Then put the game on the device:

1. Connect the iPhone to the Mac and open it in **Finder**. Go to the **Files** tab, open **NFSU2**, and drag your game
   folder (the one with `SPEED2.EXE` and the `CARS`, `TRACKS`, `SOUND` folders) into the **Game** folder there.
   The Files app on the iPhone works too: *On My iPhone > NFSU2 > Game*.
2. Open the app from the home screen.

To see the log, run from Xcode, which shows it in Xcode's console. When the app is started from the home screen, the
log goes to `Documents/Logs/nfsu2.log` instead (*On My iPhone > NFSU2 > Logs*).

## Playing

- **Menus:** a tap is a click and a drag moves the cursor, as in the browser version on phones. **Two fingers** are
  Escape, which goes back in the menus and opens the pause menu in a race.
- **Driving:** an on-screen controller (left stick to steer, RT for gas, LT for brake, A, B, X and Y). It hides when
  a real controller connects (Xbox, DualSense, MFi), and comes back when that controller disconnects.
- **Keyboard:** on an iPad with a keyboard, the keys work as on a PC.
- The game pauses when you leave the app. iOS does not let a game run in the background.

**`Documents/settings.ini`** is the Mac app's settings file, and every option there works. Useful ones on iOS:

| Setting | What it does |
|---|---|
| `NFSMAXPIX = 3000000` | Render at more pixels. The app's default caps it near 2 megapixels, about the web version's 75% on a big phone. |
| `NFSU2_TOUCH_PAD = 0` | No on-screen controller. |
| `NFSU2_AUDIO_PLAYBACK = 1` | Play sound even with the silent switch on. |
| `NFSU2_BC_UNPACK = 0` / `1` | Force DXT textures to be kept compressed (an M-chip iPad) or unpacked. The app picks this itself. |

## What is different from the Mac app

| File | Change |
|---|---|
| `runtime/metal.m` | A UIKit window and view instead of AppKit, touch to mouse (with the web build's one-change-a-frame queue), a run-loop pump in the frame loop, no drawing in the background, and DXT textures unpacked to BGRA8 where the GPU has no BC formats (every iPhone) |
| `runtime/ios_app.m` | **New:** the app and scene delegates, which start `tests/boot.c`'s main, plus the alerts |
| `runtime/keyboard_ios.m` | **New:** hardware keyboard through `GCKeyboard`, which stands in for `keyboard_mac.m` |
| `runtime/audio.m` | RemoteIO and the audio session (route changes, interruptions) instead of the Mac's default output device |
| `runtime/bundle.m` | `Documents/` instead of *Application Support*, and the game in `Documents/Game` instead of a folder picker |
| `runtime/fpscounter.m`, `texrep.m`, `gamepad.m`, `perflog.c`, `winsock.c` | macOS-only pieces left out on iOS. Texture packs need BC formats, so they only work on an M-chip iPad. |
| `ios/` | `build.sh` (compiles to `out/ios/`), the XcodeGen project, `Info.plist`, entitlements, `main.m` |

Every change is behind `TARGET_OS_IPHONE`, so the Mac build is untouched.

## Not there yet

- **Online:** free roam and online races with nfsu2.xyz players. The browser version reaches the server through the
  page, and the native builds have no client for it. LAN play over Wi-Fi might work (it is the Mac's code), but it is
  untested.
- **Touch driving made for touch:** the browser version has its own touch controls (steering zones, a drift button,
  layout settings). This port uses Apple's generic on-screen controller instead.
- **The simulator:** `ios/build.sh` builds for devices only.

## If it does not work

- **Signing fails over the entitlements:** remove the two keys from `ios/NFSU2.entitlements` and try again. If the app
  then stops at start with `mmap 4GB` in the log, the address space is the problem, and it needs a paid account.
- **The compile fails in a `runtime/*.m` file:** the error points at iOS code that has never met a compiler. Most fixes
  are a missing `#if TARGET_OS_IPHONE` around a macOS-only call.
- **The debugger stops with `EXC_BAD_ACCESS`:** that is a real crash. The game's memory has no expected faults, and
  the SIGSEGV handler only writes diagnostics.
- **Black screen with sound:** look in the log for `metal:` lines. `shader did not compile` means the shader source
  uses something an iPhone GPU lacks.
- **Nothing happens on a tap:** look for `metal: screen ... pixels` in the log. If the view size there is wrong, the
  tap positions are wrong too.
