# Keyli ⌨️

Modern, lightweight macOS menu bar keyboard viewer and interactive floating keyboard.

## Features

- **Menu Bar Quick Viewer**: Instant access to your active keyboard layout from the macOS menu bar.
- **Floating Interactive Keyboard**: Pin, drag, and resize a non-activating floating keyboard above all windows.
- **Focus-Preserving Typing**: Type into any text editor (Notes, TextEdit, VS Code, Terminal) without losing focus.
- **Live Physical Key Monitoring**: Visualize real-time physical key presses with responsive animations.
- **Dynamic Character Mapping**: Accurately reflects current macOS input source and modifier states (Shift, Option, Shift+Option) using `UCKeyTranslate`.
- **Themes & Theme Studio**: Choose from built-in themes (Dark Mechanical, Minimalist Light, Midnight Neon, Cyberpunk, Classic Retro, Frost Glass) or design custom themes in the live Theme Studio.
- **Zero Telemetry**: Fully offline, private, and lightweight native Swift/SwiftUI app.

## Requirements

- macOS 14.0 Sonoma or later
- Apple Silicon or Intel Mac

## Development

```bash
cd app/project
npm run build      # Build release .app bundle
npm test           # Run unit tests
npm run ship       # Test, build, install, and launch
```
