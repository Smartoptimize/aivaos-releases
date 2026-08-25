# AIVAOS Releases

Official public release feed for AIVAOS installers, checksums, and update metadata.

Download the current approved release:

https://github.com/Smartoptimize/aivaos-releases/releases/latest

## What To Download

- Apple Silicon Mac (M1, M2, M3, M4): `AIVAOS-<version>-mac-arm64.dmg`
- Intel Mac: `AIVAOS-<version>-mac-x64.dmg`
- Windows 10 and Windows 11: `AIVAOS-<version>-win-x64.exe`
- Checksums: `SHA256SUMS`

## Install On Mac

AIVAOS requires macOS 12.0 or newer.

1. Download the correct Mac install file for your computer (its name ends in `.dmg`).
2. Open your Downloads folder and double-click the file you just downloaded.
3. Drag the AIVAOS icon on top of the Applications folder.
4. Open your Applications folder and double-click AIVAOS.

The Mac version is signed by Apple, so it should open normally. If your Mac ever asks you to confirm, hold the **Control** key and click AIVAOS, choose **Open**, then confirm **Open**. If you still do not see an Open choice, open the Apple menu, choose **System Settings**, click **Privacy & Security**, scroll down, and click **Open Anyway** next to AIVAOS.

## Install On Windows

AIVAOS works on Windows 10 and Windows 11.

1. Download `AIVAOS-<version>-win-x64.exe` (its name ends in `.exe`).
2. Open your Downloads folder and double-click the file.
3. You will see a blue box that says **"Windows protected your PC."** This is normal for a brand new app. It does not mean anything is wrong.
4. Click the small **More info** link inside that blue box. (If you first see only a **Don't run** button, ignore it. The **More info** link is near that button.)
5. Click the **Run anyway** button that appears.
6. Windows may then ask **"Do you want to allow this app to make changes to your device?"** Click **Yes**.
7. Follow the setup screens.

That blue box shows up because AIVAOS is brand new and not yet registered with Microsoft. AIVAOS is safe to install: it comes straight from your official AIVAOS release page. The **More info**, then **Run anyway**, then **Yes** steps are all you need.

## Run AIVAOS On A Server (Linux)

These scripts install the AIVAOS localhost server and keep it running on a Linux
server, so your AI team keeps working when your own computer is asleep.

Install:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Smartoptimize/aivaos-releases/main/install-linux.sh)
```

Keep it running across reboots:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Smartoptimize/aivaos-releases/main/vps-service-linux.sh)
```

Update to the newest release. Download this one to a file first — it needs
`install-linux.sh` sitting next to it, so streaming it straight into `bash` will not
work:

```bash
curl -fsSL -o vps-update-linux.sh https://raw.githubusercontent.com/Smartoptimize/aivaos-releases/main/vps-update-linux.sh
curl -fsSL -o install-linux.sh    https://raw.githubusercontent.com/Smartoptimize/aivaos-releases/main/install-linux.sh
bash vps-update-linux.sh
```

## Source Code Privacy

This public repository is only the release feed. It does not contain the private AIVAOS product source code.

Customers should not clone the source repo, run build commands, handle signing credentials, or use GitHub as part of normal setup.

## Updates

AIVAOS uses this release feed for approved customer downloads and app updates. Installed copies check this feed on launch and every six hours, download verified updates in the background, and install them when the app is next closed. Customers install AIVAOS from release assets; the product codebase stays private.
