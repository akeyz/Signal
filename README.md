# Signal

A macOS menu-bar status light app — a breathing LED that lives in your status bar.

## Features

- **Breathing LED** in the menu bar with a 3D glow effect
- **Three colors**: 🟢 Green (calm) → 🟡 Yellow (caution) → 🔴 Red (alert)
- Each color breathes at a different speed (red = fastest, green = slowest)
- **CLI companion** (`sgnl`) for scripting and automation
- **LSUIElement** — no Dock icon, pure menu-bar app
- macOS 14+ (Sonoma)

## Build & Run

```bash
make build    # Build release binary & .app bundle
make run      # Build and launch
make install  # Copy to /Applications + ~/.local/bin
make clean    # Remove build artifacts
```

## CLI Usage

```bash
sgnl red       # Switch to red   (fastest breathing, ~1.2s cycle)
sgnl yellow    # Switch to yellow (medium breathing,  ~2.4s cycle)
sgnl green     # Switch to green  (slowest breathing, ~4.0s cycle)
sgnl help      # Show help

sgnl breath off # close effect
```

### Automation Examples

```bash
# Turn red on test failure
if ! make test; then sgnl red; fi

# CI status monitor
sgnl green   # deploy succeeded
sgnl red     # deploy failed
```

## Architecture

```
signal/
├── Package.swift              # SwiftPM manifest
├── Makefile                   # Build system
├── Resources/
│   └── Info.plist             # LSUIElement = true
└── Sources/
    ├── Signal/
    │   ├── main.swift         # NSApplication entry point
    │   └── AppDelegate.swift  # Status item, animation, IPC
    └── sgnl/
        └── main.swift         # CLI → DistributedNotification
```

**IPC**: The CLI tool posts a `DistributedNotification` (`com.signal-light.colorChange`) that the app observes. No sockets, no files — just the macOS notification bus.

## Requirements

- macOS 14.0+ (Sonoma)
- Swift 5.9+
- Xcode Command Line Tools
