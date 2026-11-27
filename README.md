# Notchpad

Notchpad turns the notch on a MacBook into a small panel. Move the mouse onto the notch and it opens with the song playing in Apple Music or Spotify, a shelf for files, your reminders, your next event and a focus timer. Move the mouse away and it goes back to being a normal black notch. On a Mac without a notch it draws a small black one in the middle of the menu bar.

![Notchpad open under the notch](docs/screenshot.png)

![Notchpad launch video](docs/notchpad-launch.gif)

The video shows version 1.6: turning the volume up from the Music widget, right-clicking a song to add it to a playlist, and a second tab with the Clipboard, Mirror, Quick note and World clock widgets. The same video with sound: [notchpad-launch.mp4](docs/notchpad-launch.mp4) (download).

## Install

Notchpad needs macOS 14 or later. With Homebrew:

```bash
brew install --cask alperengokbak/notchpad/notchpad
```

Update later with `brew upgrade --cask notchpad`. The first time you open it, do the "Open Anyway" step in point 3 below.

Or download the zip:

1. Download **Notchpad-1.7.0.zip** from the [latest release](https://github.com/alperengokbak/notchpad/releases/latest).
2. Double-click the zip, then drag **Notchpad.app** into your Applications folder.
3. Open it. macOS says it can't check the app, because it isn't notarised by Apple. Go to **System Settings → Privacy & Security**, scroll down and click **"Open Anyway"**. You only do this once.

Notchpad has no Dock icon and no menu bar icon. Move the mouse onto the notch to open it. To start it with your Mac, click the gear at the top right of the open panel (or right-click the panel) and tick "Launch at login".

When you install a newer version, macOS may ask for the permissions again (Calendar, Reminders, Music). That's because the download isn't signed with a paid Apple developer certificate.

If you'd rather build it yourself, see [Build](#build).

## What's new in 1.7

- **Pin files on the shelf.** Hover a file and click the orange pin to keep it on the shelf. A pinned file stays after you drag it into an email or a website's upload box, so a CV or a form you send again and again is always one drag away. Pinned files come first and show a small pin; "Clear shelf" leaves them alone, and "Unpin all" is in the Shelf's right-click menu.

## What's new in 1.6.1

- **External monitors.** The settings menu has a new "Show on" list. "Screen with the mouse" makes Notchpad follow the pointer between the MacBook notch and your monitor, or you can keep it on one screen. The old "Show on the main display" switch only worked when the monitor was set as the main display in System Settings, so it often did nothing.
- **New launch video** showing the volume bar, the right-click menus and a second tab of widgets.

## What's in the panel

- **Music:** the song playing in Apple Music or Spotify, with its cover, a progress bar, and previous, play/pause and next. Drag the white dot on the progress bar, or click anywhere on the bar, to jump to that point in the song. The volume bar sets the Mac's own volume, so it works for any app playing sound. Drag it and the sound changes as you drag. Click the speaker to mute or unmute. In the Medium size the bar sits under the song title; in the Small size it stands upright on the right. If you use both, it shows whichever one is playing. When both are paused it stays on the one you used last. Notchpad never starts either app by itself. If the app is closed, there's an "Open Music" or "Open Spotify" button.
- **Shelf:** drag files onto the notch and they wait there until you drag them out somewhere else. The shelf keeps a link to the original file (no copies) and is still there after a restart. When you drag a file towards the closed notch, the panel opens by itself. Hover a file and click the orange pin to keep it there even after you drag it out (handy for a CV), or the blue AirDrop icon to send it to your iPhone or another Mac, or pick "AirDrop all files" from the settings menu (the gear, or right-click). If the tab on screen has no Shelf when you drop a file, the panel switches to a tab that has one.
- **Reminders:** every reminder from every list, overdue and soonest first and ones without a date at the end. Scroll the list to see them all. Tick the circle to complete one. To delete one without completing it, hover it and click the trash icon, then click Delete. Click the + to add a reminder, or click a reminder to change its title, due date, time or list, or to delete it. In the editor, Return saves and Esc cancels. Click the Reminders heading to jump to a tab with the full list, or to the Reminders app if you don't have one. The Reminders app doesn't need to be open.
- **Next:** your next event today, from every calendar the Calendar app shows. At Medium size it lists your next three events today instead of one. Click the + to add an event, or click an event to change its title, time or calendar, or to delete it. To delete an event quickly, hover it and click the trash icon, then click Delete. For a repeating event, only that one occurrence changes. Events from calendars you can't change (subscriptions, birthdays) open read-only, with a button to open them in Calendar.
- **Music on the closed notch:** while a song plays in Apple Music or Spotify, its cover sits left of the closed notch and four small bars move on the right. Pause the song and both disappear. Hover either side to open the panel. If you don't want it, open the settings menu (the gear, or right-click) and untick "Show music on closed notch". Notchpad then fetches nothing extra while the panel is closed.
- **Focus timer:** pick a length with − and + (5 to 180 minutes, in 5-minute steps), or click the number and type one (for example 40, 1:30 or 1h15), then click Start. Notchpad remembers the length you used last, and shows how many minutes you focused today and this week (a focus you stop early counts the minutes you did). When you close the panel, the countdown stays visible on a small black strip left of the notch (red dot for focus, green for a break). When the time is up you hear a sound and get a notification, then you can start a 5 minute break or go again.
- **Tailscale:** your Tailscale status, a Connect/Disconnect button and your devices. Click a device to copy its Tailscale IP. It uses the command line tool inside the Tailscale app, so it only works if Tailscale is installed. If the Tailscale app isn't running when you click Connect, Notchpad starts it first. It checks every 5 seconds, and only while the Tailscale widget is on screen.
- **Shortcuts:** one-click icons for the apps, shortcuts and folders you use most. Click the Add tile (always right after the last icon) and choose App…, Shortcut (any shortcut you made in the Shortcuts app) or Folder…. The folder picker opens in CloudStorage, where Google Drive for desktop keeps "My Drive". Click an icon to open the app, run the shortcut, or open the folder in Finder. Drop files on a folder icon to copy them into it; the originals stay where they were. Hover an icon to remove it, or drag it onto another icon to change the order. Bigger sizes show the icons' names.
- **Mirror:** your camera as a mirror, to check how you look before a call. The camera only turns on when you click the widget, and it turns off when you click again, close the panel or switch tabs.
- **Clipboard:** the last 30 things you copied (text, links and pictures). Click one to copy it again, hover it to remove it, or click Clear. Notchpad only watches the clipboard while this widget is on one of your tabs, and it skips anything a password manager marks as secret. Text is kept on your Mac between restarts; pictures only until you quit Notchpad.
- **Recent files:** the files you opened in the last week, newest first, found with Spotlight. Click one to open it, drag it out into another app, or hover it and click the magnifying glass to show it in Finder.
- **World clock:** the time in the cities you choose, with how far ahead or behind they are (+3 h) and "Tomorrow" when it's already past midnight there. It starts with your own city; click + to add more from a menu grouped by region, and hover a city to remove it.
- **Quick note:** click it and type a short note, like a phone number or an idea in a lecture. Click elsewhere, press Esc or click Done to finish. It's saved as you type and stays until you click Clear.

## Tabs and widgets

Each part of the panel is a widget, and you choose which widgets go on which tab. Click the gear at the top right of the open panel (or right-click the panel) and pick "Edit widgets…". In edit mode you can:

- remove a widget with its minus button, or change its size with the arrows button (Small, Medium, Wide or Full, depending on the widget)
- drag a widget to an empty spot, or onto another widget to swap the two
- drag a widget onto another tab's name to move it to that tab; the panel then shows that tab (red means that tab already has the widget or has no room)
- click "Add widget" to open the gallery, search or pick a category, and click a widget to add it to the tab you're on (if that tab is full, it goes on a new tab)
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
| Clipboard | Medium, Wide, Full |
| Recent files | Medium, Wide, Full |
| World clock | Small, Medium, Wide |
| Quick note | Small, Medium, Wide |

Small is half a column, Medium is one column, Wide is two columns and Full is the whole tab.

Click Done when you're finished. You can have up to four tabs, and the same widget can be on more than one tab. The first time you open Notchpad you get one tab, Home. Add more with the + next to your tabs, for example a Reminders tab with the Full reminders widget, or a Tailscale tab. New tabs go right after the last one, and when space gets tight the tabs get a little narrower instead of jumping across the notch. A widget only loads its data while it's on screen, so widgets on other tabs don't slow anything down.

When there's no more room left of the notch, the next tabs go to the right of it. Your layout is saved in `~/Library/Application Support/Notchpad/layout.json`. If that file gets damaged, Notchpad starts with the default layout and keeps the damaged file next to it as `layout-broken-<date>.json`.

Click the gear at the top right of the open panel, or right-click anywhere on it, for "Edit widgets…", "Choose background image…", "Reset tabs and widgets…" (back to the single Home tab of a first launch; your shelf, notes and settings stay), "Show music on closed notch", "Launch at login" and "Quit Notchpad". There's no Dock icon and no menu bar icon.

**Right-click a widget** for its own actions. They sit at the top of the menu, with the usual items under them:

| Widget | Right-click actions |
|---|---|
| Music (Apple Music) | Add to playlist (your own playlists), Add to library, Favourite, Copy song link, Show in Music |
| Music (Spotify) | Shuffle, Repeat, Copy song link, Open Spotify |
| Shelf | Open all, Show in Finder, Copy file paths, AirDrop all files, Clear shelf (keeps pinned files), Unpin all |
| Reminders | New reminder, Open Reminders |
| Next event | New event, Join the next meeting (when the event has a Zoom, Teams, Meet or Webex link), Open Calendar |
| Focus | Start 25 or 50 min, Pause/Resume, Stop, Clear today's focus history |
| Clipboard | Pause recording (shows PAUSED until you turn it back on), Clear history |
| Quick note | Copy note, Save to Apple Notes, Clear note |
| Mirror | Flip image (see yourself the way others do), Turn camera off |
| Tailscale | Connect/Disconnect, Copy this Mac's IP |
| World clock | Add city |
| Shortcuts | Add app, Add shortcut, Add folder |
| Recent files | Refresh |

A short message at the bottom of the panel confirms things like "Added to Study". Adding a streamed Apple Music song to a playlist adds it to your library first, the same as in the Music app, and takes a few seconds. Spotify doesn't let other apps change playlists, so its menu has no "Add to playlist". Apple Music on current macOS ignores shuffle and repeat set by other apps, so those are in the Spotify menu only. "Save to Apple Notes" makes a new note in your default Notes folder; macOS asks once whether Notchpad may use Notes.

The same menu has switches for: **swiping on the notch to change songs** (two fingers left for the next song, right for the previous one, with the pointer over the notch, open or closed), **showing charging on the closed notch** (a green bolt and your battery level for a few seconds when you plug in the charger), **showing the newest shelf files first**, **opening the panel when you drag files to the notch**, and **adding new screenshots to the shelf** (off at first; when it's on, every screenshot you take waits on the shelf, ready to drag into an email or a document).

**External monitor:** with a monitor connected, the menu has "Show on". Pick "Screen with the mouse" and Notchpad follows the pointer: the real notch on the MacBook, and a small drawn notch at the top centre of the monitor when you work there. Or pick one screen by name to keep it there. If you unplug the monitor, Notchpad goes back to the MacBook notch, and it moves to the monitor again when you plug it back in.

**Background image:** pick any picture (JPEG, PNG, HEIC…) with "Choose background image…". It fills the open panel, cropped evenly to its wide shape (never stretched), and is darkened so the text stays readable. It never covers or blocks a button, and the closed notch stays black. Notchpad keeps its own smaller copy, so you can move or delete the original. "Remove background image" goes back to plain black.

## Requirements

- Any Mac. On a MacBook with a notch it lives in the notch; on other Macs and external monitors it draws its own small notch at the top of the screen
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
- **Automation for Notes:** only if you use "Save to Apple Notes" on the Quick note. macOS asks the first time.
- **Notifications:** for the "Focus done" message. The sound plays either way.
- **Camera:** only when you click the Mirror widget.

**Internet:** once a day Notchpad asks GitHub whether a newer version exists (it sends nothing about you). If there is one, the gear gets a blue dot and the settings menu shows "Update available". Turn this off with "Check for updates automatically" in the settings menu; "Check for updates…" still works by hand. "Copy song link" for an Apple Music song asks Apple's public song search for the song's page (it sends only the title and artist), and "Join" opens the meeting link from your event. Nothing else goes online.

If you say no to Calendar, the Next section says "Calendar off". If you say no to Reminders, the panel says "Reminders access is off" with a button that opens the right page in System Settings.

## Licence

MIT. See [LICENSE](LICENSE).
