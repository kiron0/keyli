# Changelog

All notable changes to Keyli will be documented in this file.

## 1.0.1

### Added

- **Keycap sounds**: every key plays its own press and release sound, on the on-screen keyboard and, optionally, while you type on your Mac's keyboard. Sounds overlap without cutting each other off, held keys don't repeat, and playback runs with about 5 ms of output latency.
- **Sound packs**: seven built-in packs, including two original synthesized packs (Slate Thock and Quartz Tick) and five top-rated community packs. Both community pack formats are supported, with single-file sprites, one file per key, and separate release sounds.
- **Sounds settings**: a new Sounds page with on/off, volume, pack picker, preview, and import of a pack as a .zip file or a folder. Imports are checked, and anything wrong gets a clear message.
- **Browse Packs**: search and install community packs from inside Keyli, sorted by Top Rated, Most Downloaded or Newest. Downloads are checksum-verified, and installed packs can be previewed before you use them.
- **Shortcuts**: a new Shortcuts page with global shortcuts for showing the keyboard, keep on top, physical key highlighting, input sources, Emoji & Symbols, key sounds, next sound pack, next theme, Settings, Theme Studio and update checks.
- **Input source menu**: the menu bar icon shows your current input source and lists your input sources, with Emoji & Symbols and Open Keyboard Settings.
- **Lock Position**: a lock button on the keyboard, a toggle in the keyboard menu and Settings › Keyboard, and a shortcut keep the keyboard from being moved or resized. Keep on Top now has its own window icon so the two are no longer confused.
- **Natural-sounding keys**: each press varies pitch and loudness slightly, and packs that ask for it (`random_pitch`, `recommended_volume`) are honored. Turn it off with **Vary each key slightly**.
- **Quiet Times**: key sounds mute automatically while another app uses the microphone, such as during a call, and in apps you choose.
- **Show keystrokes on screen**: a large overlay shows the shortcuts you press, or every key, at the top or bottom of the screen. Great for screencasts and demos.
- **Hover to type**: rest the pointer on a key to press it, with a progress bar on the key and an adjustable hover time.
- **Word suggestions**: the keyboard's title bar suggests the word you're typing with Keyli; one click finishes it, matching your capitalization.
- **Snippets**: choose ⋯ › Snippets on the keyboard to type a saved phrase or send a recorded shortcut.
- **Show automatically in text fields**: the keyboard can appear when you click into a text field and hide again when you leave, with a list of apps to skip. Works in Electron apps such as VS Code, Slack and Claude. Password fields are ignored.
- **Pack favorites and search**: star packs, search installed packs in a new picker with previews, and cycle only your favorites with the Next Sound Pack shortcut. The physical keyboard can have its own volume.
- **Sounds in Setup Assistant**: a new Sounds step to turn on keycap sounds, pick a pack, set the volume and preview it.
- **Tidier settings**: options that depend on a switch only appear when it's on. Sound packs are installed from Browse Packs, so the separate Import Pack button is gone.

### Changed

- **Emoji & Symbols opens natively**: Keyli now opens the Emoji & Symbols item from the menu of the app you're typing in, which is faster and works whatever your Globe key or shortcut settings are. It falls back to the keyboard shortcut only for apps without that menu item.
- **Simpler menu bar menu**: items read Show Keyboard, Settings…, Emoji & Symbols and Quit.
- **Search when you're ready**: Browse Packs searches when you press Return or click the Search button next to the field, and more packs appear as you scroll. The Mechvibes credit now sits at the top of the list.

- **Faster pack browsing**: results are cached, search runs as you type, more packs load as you scroll, and requests are paced so the catalog is never flooded.
- **Lighter background typing**: when key sounds are on but the keyboard is hidden, Keyli no longer redraws the keyboard for every key you type, and switching apps only refreshes what changed.
- **Menu bar icon**: input source icons are cached instead of being looked up on every change.

### Fixed

- **Stuck key sounds**: a key no longer goes silent after a missed key release, such as when Secure Input turns on or the keyboard closes mid-press.
- **Audio device changes**: key sounds come back right away after switching speakers or headphones.
- **ISO Return key**: the ISO layout now has a real L-shaped Return key with its label in the top part, a full-width caps lock, and the key beside Return in the right place.
- **Window buttons on the keyboard**: locking the keyboard's position no longer brings back the macOS close, minimize and zoom buttons. The lock now only blocks moving and resizing.
- **Key sound volume**: the volume setting now always controls key sounds, including the new per-key variation.
- **Smooth pack installs**: installing a pack from Browse Packs no longer freezes Settings while the pack is unpacked and checked.
- **Rare crash on layout refresh**: reading the current input source from two places at once could crash Keyli. It's now serialized.

## 1.0.0

First release of Keyli, an on-screen keyboard for macOS that types without stealing focus.

- **Floating keyboard**: a non-activating panel that types into the app you're using, from the menu bar or a resizable floating window. Resizing keeps the keyboard's proportions, and Pin keeps it above other windows.
- **Focus-safe typing**: Unicode and key code input, key repeat while holding a key, sticky modifiers, and a clear message when Secure Input is on, permission is missing or no app is targeted. Typing while a Keyli window is frontmost switches back to the last app and types there.
- **Real Mac layouts**: US ANSI, ISO, JIS and Compact layouts with labels from your current input source, plus an input source picker in Settings › Keyboard.
- **Function row and fn**: brightness, Mission Control, Spotlight, media, volume and lock keys. Tapping fn does what your Globe key does in System Settings; holding it latches F1–F12. fn + arrows, delete and return send Home, End, Page Up, Page Down, Forward Delete and Enter.
- **Physical key highlighting**: optionally lights up the keys you press on your real keyboard, only while a keyboard is visible.
- **52 built-in themes**, including Ember Graphite, macOS Native (follows light and dark mode), Layered Flat styles, and Kiln, Concrete, Oxblood, Riso Print, Olive Grove, Blacklight, Dune and Mustard.
- **Theme Studio**: search, duplicate, rename, live edit, delete, and import or export themes as JSON. Built-in themes are read-only.
- **Settings**: Keyboard, Typing, Themes, General, Permissions and About pages, with Classic or Liquid Glass window style.
- **Permissions**: Accessibility, Input Monitoring and Open at Login with live status and one-click Allow, Repair and Relaunch. Signed with a stable requirement so permissions survive updates.
- **In-app updates**: verified updates from GitHub Releases. Checks a few times a day, can download and prepare updates in the background, and installs with Restart to Update. Options in Settings › General, plus Check for Updates in the menu bar, keyboard options menu and About.
- **Private**: no account, tracking or analytics, and keystrokes are never logged.
