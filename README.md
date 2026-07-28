# TinyTroupe

TinyTroupe is a small, native macOS menu bar animation app. It is self-contained:
all animation code, pixel frames, and artwork live in this repository.

## Features

- Six-frame pixel cat and eight-frame Japanese prostration animations.
- Multiple simultaneous menu bar animations.
- Independent animation selection, mirroring, pause, and removal per item.
- Persistent item count, order, and settings.
- An app-wide launch-at-login toggle backed by macOS Login Items.
- A fixed 120 ms frame interval.
- Light and dark menu bar support through template images.
- No Dock icon, monitoring, analytics, or network access.

The first launch creates one prostration status item. Open any item menu to add
another prostration figure or pixel cat. Each item keeps its own animation, direction,
and pause state. TinyTroupe restores the complete list on the next launch.

## Run from source

Requirements: macOS 13 or newer and Xcode 16 or a compatible Swift 6 toolchain.

```sh
swift run TinyTroupe
```

## Build an app bundle

```sh
./scripts/build-app.sh x86_64
./scripts/build-app.sh arm64
./scripts/build-app.sh universal
```

Generated apps are written below `dist/<architecture>/` and ad-hoc signed for
local use. Omitting the architecture builds the Universal 2 app.

## Build DMG installers

```sh
./scripts/package-dmg.sh
```

This produces separate Apple Silicon and Intel installers. Pass `x86_64`,
`arm64`, or `universal` to build only one variant.

## GitHub Actions

The `Build macOS installers` workflow builds two downloadable DMG artifacts:

- `TinyTroupe-macOS-Intel` for Intel Macs (`x86_64`).
- `TinyTroupe-macOS-Apple-Silicon` for M-series Macs (`arm64`).

Run the workflow manually from the Actions page, or push a version tag such as
`v1.5.0`. Artifacts are retained by GitHub Actions for 30 days.

## Test

```sh
swift test
```
