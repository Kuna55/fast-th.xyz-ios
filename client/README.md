# NFSU2 client for iPhone and iPad

This app is [nfsu2.xyz](https://nfsu2.xyz/) in a full-screen window, the way
[nfsu2desktop](https://github.com/DJTOMATO/nfsu2desktop) is on Windows. The game, your saves and online play (free roam,
races, crews) are the website's own, so you play with everyone else on nfsu2.xyz. It is unofficial: it is not made or
endorsed by nfsu2.xyz or Electronic Arts.

**It needs iOS 26 or iPadOS 26.** The site's graphics need WebGPU, which iOS added in version 26.

## What it adds over Safari

- **Full screen:** no browser bars, the Home indicator is hidden, and a swipe from an edge goes to the game first.
- **The screen stays on** while you play.
- **Sound plays even with the silent switch on**, and mixes with your music app.
- **The page treats the app as a Home Screen app,** so it doesn't ask you to add it there.
- **Links to other sites** (Discord, Ko-fi) open in Safari.
- **Downloads** (the log, save backups) go to Files, under *On My iPhone > NFSU2 > Downloads*.

The app keeps its own saves, separate from Safari's. Use the site's **Cloud saves** passphrase to bring yours over.

## Install it (no Mac needed)

Every push to `client/` makes GitHub build the app. The newest build is the file `NFSU2-unsigned.ipa` on the
[client release](https://github.com/gabe4tw/nfsu2.xyz-ios/releases/tag/client) of this repo. It is unsigned, and
the installer signs it with your Apple ID.

**With [Sideloadly](https://sideloadly.io/) on Windows** (a free Apple ID works):

1. Install iTunes and iCloud for Windows from Apple's website (not the Microsoft Store versions), then Sideloadly.
2. Connect the iPhone with a cable and trust the computer on the phone.
3. Drag `NFSU2-unsigned.ipa` into Sideloadly, enter your Apple ID, and press **Start**.
4. On the iPhone, go to **Settings > General > VPN & Device Management**, tap your Apple ID, and choose **Trust**.
5. The first time, also turn on **Settings > Privacy & Security > Developer Mode** and restart the phone.

**Other signers:** [AltStore](https://altstore.io/) and SideStore sign with your Apple ID too. **Ksign** signs on the
phone with a certificate file you import (a `.p12` and a `.mobileprovision`). In Safari on the phone, log in to
GitHub, download the `.ipa` from the release, open it in Ksign and sign it. A shared certificate from a seller works,
but Apple revokes those from time to time, and then you sign the app again with a new one. None of these needs JIT:
the game runs in iOS's own web engine.

**A free Apple ID's app stops opening after 7 days.** Install it again (Sideloadly can re-sign it for you when it
runs on the same Wi-Fi). Your saves stay: they are only lost if you delete the app.

## If something is wrong

- **"This browser has no WebGPU"** on the start page: update the device to iOS 26.
- **A blank or black page:** the app reloads the page by itself if it crashes. If it stays blank, close the app
  from the app switcher and open it again.
- **Online drops when you switch apps:** iOS pauses every app you leave, so stay in the app while you're online.
- **The log for a bug report:** use the site's own *Download log* (F9 menu, or the ☰ button). It lands in
  Files > NFSU2 > Downloads.
