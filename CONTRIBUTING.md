# Contributing to Keyli

Thanks for helping improve Keyli. Bug reports, theme ideas and pull requests are all welcome.

## Report a bug or suggest an idea

Open an issue on [GitHub](https://github.com/kiron0/keyli/issues/new). For bugs, include your macOS version, Keyli version (Settings › About), the app you were typing into, and steps to reproduce.

## Build from source

Requires macOS 14 or later and the Xcode command line tools. Node is only used to run the scripts below.

```bash
cd app/project
npm run build      # build the release .app into .build/Keyli.app
npm test           # run the unit tests
npm run ship       # test, build, install to /Applications and launch
```

`npm run ship` replaces `/Applications/Keyli.app` and relaunches it. Builds are signed ad hoc with a stable identity, so macOS keeps Accessibility and Input Monitoring permissions between builds.

## Project layout

| Path | What lives there |
|---|---|
| `Sources/Keyli/App` | App entry point, `AppDelegate`, `KeyboardCoordinator` |
| `Sources/Keyli/Core` | Models, config, themes, layout engine, input dispatch, permissions |
| `Sources/Keyli/UI` | Keyboard renderer, floating panel, Settings, Theme Studio |
| `Tests/KeyliTests` | Unit tests (Swift Testing) |
| `Scripts` | Build, ship, version bump and icon renderer |
| `Support` | Info.plist, icons, README screenshots |
| `../docs` | Architecture, design, rules and working notes |

## Guidelines

- Read `../docs/memory.md` and `../docs/rules.md` before changing code.
- Typing must never steal focus: keyboard panels stay `NSPanel` with `.nonactivatingPanel`.
- Keep rendering separate from input injection. Each keyboard is drawn in one `Canvas`; don't go back to one view per key.
- Physical key monitoring stays listen-only, off by default, and never records or stores keystrokes.
- Don't add code comments; keep names and structure self-explanatory.
- New themes need an original name (not another product's name) and valid colors; `ThemeTests` checks both.
- Run `npm test` before opening a pull request, and include a screenshot for visual changes.

## App icon

The icon is drawn in code. To change it, edit `Scripts/icon/render-icon.swift`, then:

```bash
swiftc -O Scripts/icon/render-icon.swift -o /tmp/render-icon
/tmp/render-icon Scripts/icon/squircle.txt /tmp/keyli-icon.png
```

Then rebuild `Support/Icons/AppIcon.iconset` with `sips` and `iconutil -c icns`.
