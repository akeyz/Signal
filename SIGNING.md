# Code Signing & Gatekeeper Guide

Because Signal is distributed outside the Mac App Store and relies on ad-hoc (self) signing by default, you may see a Gatekeeper warning stating that the app is "damaged" or from an "unidentified developer" when running it on another machine.

This document describes how to configure official code signing for distribution, or how to bypass these security warnings for local development and testing.

---

## 1. Official Code Signing (For Distribution)

If you have a paid Apple Developer Account, you can sign both the application bundle and the generated DMG.

### Prerequisites
You must have a **Developer ID Application** certificate installed in your macOS Keychain. You can find its name in the Keychain Access app (e.g., `"Developer ID Application: Your Name (TEAMID)"`).

### How to Sign
Pass your signing identity when running `make dmg` or `make build`:

```bash
# Package the DMG and sign both the app bundle and the DMG file
make dmg CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"

# Or build the app bundle and sign it
make build CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
```

### Notarization & Stapling
To completely avoid Gatekeeper blocks, you must submit the signed DMG to Apple's Notary Service:

1. **Submit for Notarization**:
   ```bash
   xcrun notarytool submit .build/Signal.dmg --apple-id "your-apple-id" --team-id "YOUR_TEAM_ID" --password "your-app-specific-password" --wait
   ```
2. **Staple the Ticket**:
   Once approved, attach the notarization ticket to the DMG:
   ```bash
   xcrun stapler staple .build/Signal.dmg
   ```

---

## 2. Gatekeeper Bypass (For Local Testing)

If you compile the app locally or download an unsigned/ad-hoc signed DMG, macOS may prevent the app from launching. You can bypass this using one of the following methods.

### Method A: Right-Click Open (Recommended)
1. Locate `Signal.app` in Finder (typically in `/Applications`).
2. **Right-click** (or Control-click) the application icon and choose **Open** from the context menu.
3. A warning dialog will appear. Click **Open** (or **Open Anyway**) to confirm.
4. macOS will remember this preference, and the app will open normally in the future.

### Method B: Terminal Command (Clear Quarantine Flag)
When apps are downloaded or copied over networks, macOS attaches a `com.apple.quarantine` extended attribute. You can remove this flag using the `xattr` tool in your terminal:

```bash
xattr -d com.apple.quarantine /Applications/Signal.app
```
Once run, the app will launch immediately without warnings.
