# Flicker

**[中文](README.md)** | English

<p align="center">
  <a href="https://www.apple.com/macos/"><img src="https://img.shields.io/badge/macOS-14%2B-blue" alt="macOS 14+" /></a>
  <a href="https://swift.org"><img src="https://img.shields.io/badge/Swift-6.0-orange" alt="Swift 6.0" /></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-green.svg" alt="License: MIT" /></a>
</p>

A minimalist macOS Finder right-click menu extension — open files and folders with your pre-configured apps instantly.

## Features

- Right-click files/folders to open with pre-configured applications
- Copy absolute or relative paths to clipboard
- Configure app list with per-app file extension filters inside the container app
- "Folders only" mode for fine-grained menu visibility control

## Project Structure

```
Flicker/
├── App/          # App entry, config list, add/edit panels, store
├── Shared/       # AppEntry (data model), SharedStore (App Group read/write)
└── Resources/    # Info.plist, entitlements, Assets

FlickerExtension/   # Finder Sync extension (FIFinderSync subclass)
```

## Getting Started

### Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 16+ (for building)

### Build & Run

```bash
# Command-line build
xcodebuild -project Flicker.xcodeproj -scheme Flicker -configuration Debug build

# Or open Flicker.xcodeproj in Xcode, select the Flicker scheme and hit Run
```

### Package as DMG

```bash
./scripts/build_dmg.sh
# Output: dist/Flicker.dmg
```

### Enable the Extension

1. Launch Flicker, click **Add** to select a `.app`, set its name and applicable file extensions
2. Click **Enable Finder Extension…** at the bottom, then check Flicker under **System Settings → Privacy & Security → Extensions → Finder**
3. Restart Finder (`killall Finder`) — right-click in Finder to see the menu

## Configuration After Forking

If you fork this project and plan to build your own copy, update these values to your own:

| Setting | Current Value | Location |
|---------|---------------|----------|
| Bundle Identifier (App) | `com.wangyanan.flicker` | `project.pbxproj` |
| Bundle Identifier (Extension) | `com.wangyanan.flicker.extension` | `project.pbxproj` |
| App Group | `group.com.wangyanan.flicker` | `Shared/SharedStore.swift` |
| URL Scheme | `flicker` | `Resources/Info.plist` |

> **Tip:** App Group must be registered in the Apple Developer portal. For local development, ad-hoc signing (`CODE_SIGN_IDENTITY = "-"`) works without a developer account.

## Technical Notes

- Relative paths are based on the current Finder window folder (`targetedURL`); falls back to absolute path when unavailable
- Configuration is shared between the app and extension via App Group in JSON format
- Minimum deployment target: macOS 14.0 (Sonoma)

## Contributing

Issues and Pull Requests are welcome!

- Make sure the code compiles and runs before submitting a PR
- Open an issue first to discuss new features
- Keep code style consistent with the existing codebase

## License

This project is licensed under the [MIT License](LICENSE).
