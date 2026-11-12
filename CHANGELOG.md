# Changelog

All notable changes to Keyli will be documented in this file.

## Unreleased

### Changed
- Brightness, volume, media and Mission Control keys work even when no other app is focused.
- Typing while a Keyli window is frontmost switches back to the last app and types there instead of refusing.
- Permissions page lists Accessibility, Input Monitoring and Open at Login with live status (Waiting, Denied, Needs Repair, Relaunch Needed, Needs Approval) and refreshes when you return from System Settings.
- Theme Studio preview keys no longer type into other apps.
- Menu bar icon toggles the floating keyboard (click to show, click to hide); the separate menu bar keyboard is gone.
- Theme Studio uses the same glass window style as Settings, with theme search.
- 24 new theme presets (31 built-in).
- Smooth, flicker-free proportional resizing from any edge or corner.
- Settings window rebuilt as a glass sidebar window in the QuitX style, with permission cards (Allow, Settings, Repair, Relaunch).
- Keyboards keep their proportions: resizing the floating keyboard is ratio-locked and keys never stretch.
- Builds are signed with a stable requirement so macOS permissions survive updates.
- Native macOS interface: Theme Studio with sidebar and inspector, native options menu on keyboards.
- Menu bar keyboard is now a non-activating panel, so typing from it no longer steals focus.
- macOS Native theme follows system light and dark appearance.
- Physical key highlighting is off by default and only runs while a keyboard is visible.
- Function row uses full-width keys with working brightness, Mission Control, Spotlight, media, volume and lock actions; fn latches F1–F12.

### Added
- Theme duplicate, rename, live edit, delete, import from file, export to file. Built-in themes are read-only.
- Key repeat while holding a key.
- Typing refuses with a visible message when Secure Input is on, permission is missing, or there is no target app.
- Older settings and theme files keep loading after upgrades (schema version, default-filled decoding).

### Fixed
- Removed debug keystroke logging to `/tmp/keyli.log`.
- Tests no longer write themes into the user's Application Support folder.
- JIS layout space and kana keys overlapped the right command key.
- Main-thread sleeps during typing.

## 1.0.0 - 2026-10-11

### Added
- Initial release of Keyli.
- Menu Bar quick keyboard viewer.
- Non-activating floating interactive keyboard panel.
- Focus-safe typing into target applications using Unicode and keycode synthesis.
- Real-time physical keyboard input monitoring and visual feedback.
- Dynamic key label resolution with `UCKeyTranslate` and macOS input source sync.
- 6 built-in themes (Dark Mechanical, Minimalist Light, Midnight Neon, Cyberpunk, Classic Retro, Frost Glass).
- Live Theme Studio editor with custom color pickers and JSON export/import.
- Accessibility and Input Monitoring permissions manager.
- Launch at login support via ServiceManagement.
