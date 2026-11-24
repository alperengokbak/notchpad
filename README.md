# Notchpad

Notchpad turns the notch on a MacBook into a small panel. Move the mouse onto the notch and it opens with the song playing in Apple Music or Spotify, a shelf for files, your reminders, your next event and a focus timer. Move the mouse away and it goes back to being a normal black notch.

![Notchpad open under the notch](docs/screenshot.png)

![Notchpad launch video](docs/notchpad-launch.gif)

The video shows version 1.1: adding a reminder, jumping around a song with the dot on the progress bar, and typing a focus length. The same video with sound: [notchpad-launch.mp4](docs/notchpad-launch.mp4) (download).

## What's new in 1.2

- **Shortcuts widget.** One-click icons for the apps, shortcuts and folders you use most. Add it from the widget gallery, then click the Add tile after the last icon to pick an app, one of your shortcuts from the Shortcuts app, or a folder such as Google Drive's "My Drive". Drop files on a folder icon to copy them into it.

## What's new in 1.1

- **Add, change and delete reminders and events from the panel.** Click + to add one, or click a reminder or event to change it. To delete one without completing it, hover it, click the trash icon, then click Delete.
- **Every reminder in one list.** The Reminders widget now shows all your reminders, not only the first four, and you can scroll through them.
- **Any focus length.** Use − and + (5 to 180 minutes), or click the number and type a length such as 40, 1:30 or 1h15.
- **Jump around in a song.** Drag the white dot on the progress bar, or click anywhere on the bar.
- **Background image.** Pick a picture for the open panel. It fills the panel, stays behind the buttons, and is darkened so the text is easy to read.
- **Settings button.** A gear at the top right of the open panel opens the same menu as a right-click.
- **Tidier tabs.** A new tab goes right after the last one instead of jumping to the other side of the notch, and a tab you just added can be deleted straight away.
- **Simpler first launch.** New installs start with one Home tab. You can add a Reminders or Tailscale tab yourself in edit mode.

## Download

1. Download **Notchpad-1.2.0.zip** from the [latest release](https://github.com/alperengokbak/notchpad/releases/latest).
2. Double-click the zip, then drag **Notchpad.app** into your Applications folder.
3. Open it. macOS says it can't check the app, because it isn't notarised by Apple. Go to **System Settings → Privacy & Security**, scroll down and click **"Open Anyway"**. You only do this once.

Notchpad has no Dock icon and no menu bar icon. Move the mouse onto the notch to open it. To start it with your Mac, click the gear at the top right of the open panel (or right-click the panel) and tick "Launch at login".

When you install a newer version, macOS may ask for the permissions again (Calendar, Reminders, Music). That's because the download isn't signed with a paid Apple developer certificate.

If you'd rather build it yourself, see [Build](#build).

## What's in the panel

- **Music:** the song playing in Apple Music or Spotify, with its cover, a progress bar, and previous, play/pause and next. Drag the white dot on the progress bar, or click anywhere on the bar, to jump to that point in the song. If you use both, it shows whichever one is playing. When both are paused it stays on the one you used last. Notchpad never starts either app by itself. If the app is closed, there's an "Open Music" or "Open Spotify" button.
- **Shelf:** drag files onto the notch and they wait there until you drag them out somewhere else. The shelf keeps a link to the original file (no copies) and is still there after a restart. When you drag a file towards the closed notch, the panel opens by itself. Hover a file and click the blue AirDrop icon to send it to your iPhone or another Mac, or pick "AirDrop all files" from the settings menu (the gear, or right-click). If the tab on screen has no Shelf when you drop a file, the panel switches to a tab that has one.
- **Reminders:** every reminder from every list, overdue and soonest first and ones without a date at the end. Scroll the list to see them all. Tick the circle to complete one. To delete one without completing it, hover it and click the trash icon, then click Delete. Click the + to add a reminder, or click a reminder to change its title, due date, time or list, or to delete it. In the editor, Return saves and Esc cancels. Click the Reminders heading to jump to a tab with the full list, or to the Reminders app if you don't have one. The Reminders app doesn't need to be open.
- **Next:** your next event today, from every calendar the Calendar app shows. At Medium size it lists your next three events today instead of one. Click the + to add an event, or click an event to change its title, time or calendar, or to delete it. To delete an event quickly, hover it and click the trash icon, then click Delete. For a repeating event, only that one occurrence changes. Events from calendars you can't change (subscriptions, birthdays) open read-only, with a button to open them in Calendar.
- **Music on the closed notch:** while a song plays in Apple Music or Spotify, its cover sits left of the closed notch and four small bars move on the right. Pause the song and both disappear. Hover either side to open the panel. If you don't want it, open the settings menu (the gear, or right-click) and untick "Show music on closed notch". Notchpad then fetches nothing extra while the panel is closed.
- **Focus timer:** pick a length with − and + (5 to 180 minutes, in 5-minute steps), or click the number and type one (for example 40, 1:30 or 1h15), then click Start. Notchpad remembers the length you used last. When you close the panel, the countdown stays visible on a small black strip left of the notch (red dot for focus, green for a break). When the time is up you hear a sound and get a notification, then you can start a 5 minute break or go again.
- **Tailscale:** your Tailscale status, a Connect/Disconnect button and your devices. Click a device to copy its Tailscale IP. It uses the command line tool inside the Tailscale app, so it only works if Tailscale is installed. If the Tailscale app isn't running when you click Connect, Notchpad starts it first. It checks every 5 seconds, and only while the Tailscale widget is on screen.
- **Shortcuts:** one-click icons for the apps, shortcuts and folders you use most. Click the Add tile (always right after the last icon) and choose App…, Shortcut (any shortcut you made in the Shortcuts app) or Folder…. The folder picker opens in CloudStorage, where Google Drive for desktop keeps "My Drive". Click an icon to open the app, run the shortcut, or open the folder in Finder. Drop files on a folder icon to copy them into it; the originals stay where they were. Hover an icon to remove it. Bigger sizes show the icons' names.
- **Mirror:** your camera as a mirror, to check how you look before a call. The camera only turns on when you click the widget, and it turns off when you click again, close the panel or switch tabs.

## Tabs and widgets

Each part of the panel is a widget, and you choose which widgets go on which tab. Click the gear at the top right of the open panel (or right-click the panel) and pick "Edit widgets…". In edit mode you can:

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
| Shortcuts | Small, Medium, Wide |
| Mirror | Small, Medium, Wide |

Small is half a column, Medium is one column, Wide is two columns and Full is the whole tab.

Click Done when you're finished. You can have up to four tabs, and the same widget can be on more than one tab. The first time you open Notchpad you get one tab, Home. Add more with the + next to your tabs, for example a Reminders tab with the Full reminders widget, or a Tailscale tab. New tabs go right after the last one, and when space gets tight the tabs get a little narrower instead of jumping across the notch. A widget only loads its data while it's on screen, so widgets on other tabs don't slow anything down.

When there's no more room left of the notch, the next tabs go to the right of it. Your layout is saved in `~/Library/Application Support/Notchpad/layout.json`. If that file gets damaged, Notchpad starts with the default layout and keeps the damaged file next to it as `layout-broken-<date>.json`.

Click the gear at the top right of the open panel, or right-click anywhere on it, for "Edit widgets…", "Choose background image…", "Show music on closed notch", "Launch at login" and "Quit Notchpad". There's no Dock icon and no menu bar icon.

The same menu has switches for: **swiping on the notch to change songs** (two fingers left for the next song, right for the previous one, with the pointer over the notch, open or closed), **showing charging on the closed notch** (a green bolt and your battery level for a few seconds when you plug in the charger), **showing the newest shelf files first**, and **opening the panel when you drag files to the notch**.

**Background image:** pick any picture (JPEG, PNG, HEIC…) with "Choose background image…". It fills the open panel, cropped evenly to its wide shape (never stretched), and is darkened so the text stays readable. It never covers or blocks a button, and the closed notch stays black. Notchpad keeps its own smaller copy, so you can move or delete the original. "Remove background image" goes back to plain black.

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

- **Calendar:** to show your next event, and to add, change or delete events when you ask it to. Nothing leaves your Mac.
- **Reminders:** to show your reminders, tick them off, and add, change or delete them when you ask it to.
- **Automation for Music or Spotify:** to show the current song and to use the play, next and previous buttons and the progress bar. macOS asks once for each app.
- **Notifications:** for the "Focus done" message. The sound plays either way.

If you say no to Calendar, the Next section says "Calendar off". If you say no to Reminders, the panel says "Reminders access is off" with a button that opens the right page in System Settings.

## Licence

MIT. See [LICENSE](LICENSE).
