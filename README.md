# NFSU2 for iPhone and iPad

*Need for Speed: Underground 2* on iOS, in two forms:

- **The client** ([`client/`](client/README.md)): [nfsu2.xyz](https://nfsu2.xyz/) as a full-screen iPhone and iPad
  app. You play the website's game with its saves and its online world: free roam, races and crews with everyone
  else on nfsu2.xyz. It is what [nfsu2desktop](https://github.com/DJTOMATO/nfsu2desktop) is on Windows. This is the
  one to use.
- **The native build** ([`ios/`](ios/README.md)): the game compiled for iOS from your own copy of the PC game,
  without a browser. It has no online play, needs a Mac and a paid Apple developer account to build and install, and
  has not been run yet.

Both are unofficial. Neither is made or endorsed by nfsu2.xyz or Electronic Arts.

## The client

The app opens nfsu2.xyz in a full-screen web view and adds what a Safari tab lacks:

- full screen, without browser bars or the Home indicator
- the screen stays on while you play
- sound plays even with the silent switch on
- links to Discord and other sites open in Safari
- downloads (the log, save backups) go to the Files app

It needs **iOS 26 or iPadOS 26**, because the game's graphics use WebGPU, which iOS added in version 26.

### Install it

You don't need a Mac. GitHub builds the app on every change to `client/` and puts it on this repository's
[client release](https://github.com/gabe4tw/nfsu2.xyz-ios/releases/tag/client) as `NFSU2-unsigned.ipa`. You sign
it when you install it:

- **[Sideloadly](https://sideloadly.io/) on Windows** with your Apple ID. A free Apple ID works, but the app then
  stops opening after 7 days and has to be installed again. Your saves stay.
- **Ksign, AltStore or SideStore** work too. Ksign needs a certificate file of your own rather than an Apple ID.

None of them needs JIT: the game runs in iOS's own web engine. The step-by-step instructions, including the
settings to trust the app on the phone, are in [client/README.md](client/README.md).

The app keeps its own saves, separate from Safari's. To bring yours over, use the site's **Cloud saves**
passphrase.

## The native build

The native build is the [nfsu2-web](https://github.com/th0mk/nfsu2-web) project's native port, which builds the game
as a Mac app, moved to iOS:

- **How it works:** the game's x86 code is translated to C ahead of time from your own `SPEED2.EXE` (v1.2 North
  America), then compiled for arm64 and drawn with Metal.
- **What's iOS-specific:** a UIKit window, touch for the menus, Apple's on-screen controller for driving, the iOS
  audio session, and the Files app for the game folder.
- **Why there's no download:** the build contains code made from your copy of the game, so it can't be shared, and
  nothing made from the game is ever committed.

GitHub compiles its code on every change ([`ios/check.sh`](ios/check.sh)), but without the game, so nothing has been
linked or run yet. Building it takes a Mac with Xcode. Running it most likely takes a paid developer account, because
the game reserves more memory and address space than iOS gives an app by default. [ios/README.md](ios/README.md) has
the steps and what to look at when something fails.

## What's in this repository

| Path | What |
|---|---|
| `client/` | The client app (Swift), its icon and project spec |
| `.github/workflows/client.yml` | Builds the client's `.ipa` and publishes it on the `client` release |
| `ios/` | The native build: the build script, the Xcode project spec, the compile check |
| `.github/workflows/ios-check.yml` | Compiles the native build's code for iOS on every change |
| `runtime/` | The game's runtime from nfsu2-web, with the iOS parts added behind `TARGET_OS_IPHONE` |
| everything else | nfsu2-web as it was at commit [`11bdf2e`](https://github.com/th0mk/nfsu2-web/commit/11bdf2eca187492a2118889ccc4b1fb6021e1342): the lifter, the browser version and its server. [Its README](https://github.com/th0mk/nfsu2-web#readme) describes them. |

nfsu2-web's own GitHub workflows (tests, server images) are turned off in this repository.

## Credits

- **The game on the web and the native port:** [nfsu2-web](https://github.com/th0mk/nfsu2-web) by th0mk, which runs
  [nfsu2.xyz](https://nfsu2.xyz/).
- **The recompilation it builds on:** Talha Müderrisoğlu's [NFSU2Recomp](https://github.com/TalhaMudo/NFSU2Recomp),
  after the method of [N64: Recompiled](https://github.com/N64Recomp/N64Recomp) and
  [XenonRecomp](https://github.com/hedge-dev/XenonRecomp).
- **The mods and translations** the game's language packs, texture packs and fixes come from are credited in
  [nfsu2-web's README](https://github.com/th0mk/nfsu2-web#credits).
- **The idea of a desktop client:** [nfsu2desktop](https://github.com/DJTOMATO/nfsu2desktop) by DJTOMATO.

## License

MIT ([LICENSE](LICENSE)), as nfsu2-web. *Need for Speed* and *Need for Speed: Underground 2* are trademarks of
Electronic Arts Inc. This repository contains none of the game's code or data.
