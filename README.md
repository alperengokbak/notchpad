# Notchpad

Notchpad turns the notch on a MacBook into a small panel. Move the mouse onto the notch and it opens with the song playing in Apple Music or Spotify, a shelf for files, your reminders, your next event and a focus timer. Move the mouse away and it goes back to being a normal black notch.

![Notchpad open under the notch](docs/screenshot.png)

![Notchpad launch video](docs/notchpad-launch.gif)

The same video with sound: [notchpad-launch.mp4](docs/notchpad-launch.mp4) (download).

## Download

1. Download **Notchpad-1.0.0.zip** from the [latest release](https://github.com/alperengokbak/notchpad/releases/latest).
2. Double-click the zip, then drag **Notchpad.app** into your Applications folder.
3. Open it. macOS says it can't check the app, because it isn't notarised by Apple. Go to **System Settings → Privacy & Security**, scroll down and click **"Open Anyway"**. You only do this once.

Notchpad has no Dock icon and no menu bar icon. Move the mouse onto the notch to open it. To start it with your Mac, right-click the open panel and tick "Launch at login".

When you install a newer version, macOS may ask for the permissions again (Calendar, Reminders, Music). That's because the download isn't signed with a paid Apple developer certificate.

If you'd rather build it yourself, see [Build](#build).

## What's in the panel

- **Music:** the song playing in Apple Music or Spotify, with its cover, a progress bar, and previous, play/pause and next. If you use both, it shows whichever one is playing. When both are paused it stays on the one you used last. Notchpad never starts either app by itself. If the app is closed, there's an "Open Music" or "Open Spotify" button.
- **Shelf:** drag files onto the notch and they wait there until you drag them out somewhere else. The shelf keeps a link to the original file (no copies) and is still there after a restart. When you drag a file towards the closed notch, the panel opens by itself. Hover a file and click the blue AirDrop icon to send it to your iPhone or another Mac, or right-click the panel for "AirDrop all files". If the tab on screen has no Shelf when you drop a file, the panel switches to a tab that has one.
- **Reminders:** your overdue and soonest reminders from every list, with a circle to tick them off. Click the Reminders heading to jump to the tab with the full list. The Reminders app doesn't need to be open.
- **Next:** your next event today, from every calendar the Calendar app shows. At Medium size it lists your next three events today instead of one.
- **Music on the closed notch:** while a song plays in Apple Music or Spotify, its cover sits left of the closed notch and four small bars move on the right. Pause the song and both disappear. Hover either side to open the panel. If you don't want it, right-click the open panel and untick "Show music on closed notch". Notchpad then fetches nothing extra while the panel is closed.
- **Focus timer:** start a 25 or 50 minute session. When you close the panel, the countdown stays visible on a small black strip left of the notch (red dot for focus, green for a break). When the time is up you hear a sound and get a notification, then you can start a 5 minute break or go again.
- **Tailscale:** your Tailscale status, a Connect/Disconnect button and your devices. Click a device to copy its Tailscale IP. It uses the command line tool inside the Tailscale app, so it only works if Tailscale is installed. If the Tailscale app isn't running when you click Connect, Notchpad starts it first. It checks every 5 seconds, and only while the Tailscale widget is on screen.

## Tabs and widgets

Each part of the panel is a widget, and you choose which widgets go on which tab. Right-click the open panel and pick "Edit widgets…". In edit mode you can:

- remove a widget with its minus button, or change its size with the arrows button (Small, Medium, Wide or Full, depending on the widget)
- drag a widget to an empty spot, or onto another widget to swap the two
- click "Add widget" to open the gallery, search or pick a category, and click a widget to add it to the tab you're on
- add a tab with +, click the selected tab to rename it, drag tabs to change their order, or delete a tab with its minus button

| Widget | Sizes |
|---|---|
| Music | Small, Medium |
| Shelf | Small, Medium, Wide |
| Reminders | Medium, Wide, Full |
| Next | Small, Medium |
| Focus timer | Small |
| Tailscale | Medium, Full |

Small is half a column, Medium is one column, Wide is two columns and Full is the whole tab.

Click Done when you're finished. You can have up to four tabs, and the same widget can be on more than one tab. The first time you open Notchpad you get three tabs: Home, Reminders and Tailscale. If Tailscale isn't installed, you get only Home and Reminders, and you can still add the Tailscale widget from the gallery later. A widget only loads its data while it's on screen, so widgets on other tabs don't slow anything down.

When there's no more room left of the notch, the next tabs go to the right of it. Your layout is saved in `~/Library/Application Support/Notchpad/layout.json`. If that file gets damaged, Notchpad starts with the default layout and keeps the damaged file next to it as `layout-broken-<date>.json`.

Right-click the open panel for "Edit widgets…", "Show music on closed notch", "Launch at login" and "Quit Notchpad". There's no Dock icon and no menu bar icon.

## Requirements

- A MacBook with a notch (2021 MacBook Pro or newer, 2022 MacBook Air or newer)
- macOS 14 or later
- Apple Music or Spotify, for the music part

## Build

```bash
brew install xcodegen
git clone https://github.com/alperengokbak/notchpad.git && cd notchpad
scripts/build.sh
open build/Build/Products/Debug/Notchpad.app
```

`scripts/build.sh` signs the app with your "Apple Development" certificate if you have one (Xcode creates it when you sign in with your Apple ID). Otherwise it signs the app for your Mac only. With the certificate, macOS remembers the permissions between builds. Without it, it may ask again after each build.

To run the tests: `swift test --package-path Packages/NotchpadCore`

To make the download zip yourself: `scripts/release.sh`. It builds the app, signs it without a personal certificate, checks that no home-folder path, Team ID, Gmail or iCloud address is inside, and writes `build/Notchpad-<version>.zip`.

## First launch

The app isn't notarised by Apple, so the first time you open a downloaded copy, macOS blocks it. Go to System Settings → Privacy & Security and click "Open Anyway". You only do this once.

Notchpad then asks for these permissions, each once:

- **Calendar:** to show your next event. Nothing leaves your Mac.
- **Reminders:** to show your reminders and tick them off.
- **Automation for Music or Spotify:** to show the current song and to use the play, next and previous buttons. macOS asks once for each app.
- **Notifications:** for the "Focus done" message. The sound plays either way.

If you say no to Calendar, the Next section says "Calendar off". If you say no to Reminders, the panel says "Reminders access is off" with a button that opens the right page in System Settings.

## Licence

MIT. See [LICENSE](LICENSE).
