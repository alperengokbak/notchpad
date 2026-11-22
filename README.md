# Notchpad

Notchpad turns the notch on a MacBook into a small panel. Move the mouse onto the notch and it opens with the song playing in Apple Music, a shelf for files, your reminders, your next event and a focus timer. Move the mouse away and it goes back to being a normal black notch.

![Notchpad open under the notch](docs/screenshot.png)

## What's in the panel

- **Music:** the current Apple Music track with its cover, a progress bar, and previous, play/pause and next. Notchpad never starts Music by itself. If Music is closed, there's an "Open Music" button.
- **Shelf:** drag files onto the notch and they wait there until you drag them out somewhere else. The shelf keeps a link to the original file (no copies) and is still there after a restart. When you drag a file towards the closed notch, the panel opens by itself. Hover a file and click the blue AirDrop icon to send it to your iPhone or another Mac, or right-click the panel for "AirDrop all files".
- **Reminders:** your overdue and soonest reminders from every list, with a circle to tick them off. Click the Reminders heading to see all of them in the Reminders tab. The Reminders app doesn't need to be open.
- **Next:** your next event today, from every calendar the Calendar app shows.
- **Focus timer:** start a 25 or 50 minute session. When you close the panel, the countdown stays visible on a small black strip left of the notch (red dot for focus, green for a break). When the time is up you hear a sound and get a notification, then you can start a 5 minute break or go again.
- **Tailscale tab:** a third tab with your Tailscale status, a Connect/Disconnect button and your devices. Click a device to copy its Tailscale IP. It uses the command line tool inside the Tailscale app, so it only works if Tailscale is installed. If the Tailscale app isn't running when you click Connect, Notchpad starts it first. It checks every 5 seconds, and only while the tab is open.

The panel has three tabs at the top left: Home, Reminders and Tailscale. Right-click the open panel for "Launch at login" and "Quit Notchpad". There's no Dock icon and no menu bar icon.

## Requirements

- A MacBook with a notch (2021 MacBook Pro or newer, 2022 MacBook Air or newer)
- macOS 14 or later
- Apple Music, for the music part

## Build

```bash
brew install xcodegen
git clone https://github.com/alperengokbak/notchpad.git && cd notchpad
scripts/build.sh
open build/Build/Products/Debug/Notchpad.app
```

`scripts/build.sh` signs the app with your "Apple Development" certificate if you have one (Xcode creates it when you sign in with your Apple ID). Otherwise it signs the app for your Mac only. With the certificate, macOS remembers the permissions between builds. Without it, it may ask again after each build.

To run the tests: `swift test --package-path Packages/NotchpadCore`

## First launch

The app isn't notarised by Apple, so the first time you open a copy someone sent you, macOS blocks it. Go to System Settings → Privacy & Security and click "Open Anyway". You only do this once.

Notchpad then asks for these permissions, each once:

- **Calendar:** to show your next event. Nothing leaves your Mac.
- **Reminders:** to show your reminders and tick them off.
- **Automation for Music:** to show the current song and to use the play, next and previous buttons.
- **Notifications:** for the "Focus done" message. The sound plays either way.

If you say no to Calendar, the Next section says "Calendar off". If you say no to Reminders, the panel says "Reminders access is off" with a button that opens the right page in System Settings.

## Licence

MIT. See [LICENSE](LICENSE).
