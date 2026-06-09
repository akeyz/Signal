# ──────────────────────────────────────────────────────────────
# Signal – macOS menu-bar status light
# ──────────────────────────────────────────────────────────────

APP_NAME    := Signal
CLI_NAME    := sgnl
BUILD_DIR   := .build
RELEASE_DIR := $(BUILD_DIR)/release
APP_BUNDLE  := $(BUILD_DIR)/$(APP_NAME).app
INSTALL_DIR := /Applications
CLI_INSTALL := $(HOME)/.local/bin

.PHONY: build run install uninstall clean dmg help

# ── Build ────────────────────────────────────────────────────
build:
	@echo "⚙  Building $(APP_NAME) (release)…"
	swift build -c release

	@echo "📦 Assembling $(APP_NAME).app bundle…"
	mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	mkdir -p "$(APP_BUNDLE)/Contents/Resources"
	cp "$(RELEASE_DIR)/$(APP_NAME)" "$(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)"
	cp "Resources/Info.plist"       "$(APP_BUNDLE)/Contents/"
	cp "Resources/AppIcon.icns"     "$(APP_BUNDLE)/Contents/Resources/" 2>/dev/null || true
	cp -R Resources/en.lproj        "$(APP_BUNDLE)/Contents/Resources/"
	cp -R Resources/zh-Hans.lproj   "$(APP_BUNDLE)/Contents/Resources/"
	cp "$(RELEASE_DIR)/$(CLI_NAME)" "$(APP_BUNDLE)/Contents/Resources/$(CLI_NAME)"

	@echo "🔏 Ad-hoc code signing…"
	codesign --force --sign - "$(APP_BUNDLE)"

	@echo "✅ Build complete → $(APP_BUNDLE)"

# ── Run ──────────────────────────────────────────────────────
run: build
	@echo "🚀 Launching $(APP_NAME)…"
	open "$(APP_BUNDLE)"

# ── Install ──────────────────────────────────────────────────
install: build
	@echo "📥 Installing $(APP_NAME).app → $(INSTALL_DIR)/"
	cp -R "$(APP_BUNDLE)" "$(INSTALL_DIR)/"
	@echo "📥 Installing $(CLI_NAME)   → $(CLI_INSTALL)/"
	mkdir -p "$(CLI_INSTALL)"
	cp "$(RELEASE_DIR)/$(CLI_NAME)" "$(CLI_INSTALL)/$(CLI_NAME)"
	@echo "✅ Installed. Run: open /Applications/$(APP_NAME).app"
	@echo "   CLI:  $(CLI_NAME) <red|yellow|green>"

# ── Uninstall ────────────────────────────────────────────────
uninstall:
	@echo "🗑  Removing $(APP_NAME)…"
	rm -rf "$(INSTALL_DIR)/$(APP_NAME).app"
	rm -f  "$(CLI_INSTALL)/$(CLI_NAME)"
	@echo "✅ Uninstalled."

# ── DMG Packaging ───────────────────────────────────────────
dmg: build
	@echo "📦 Preparing DMG staging area…"
	rm -rf "$(BUILD_DIR)/dmg_stage"
	mkdir -p "$(BUILD_DIR)/dmg_stage"
	cp -R "$(APP_BUNDLE)" "$(BUILD_DIR)/dmg_stage/"
	ln -s /Applications "$(BUILD_DIR)/dmg_stage/Applications"

	@echo "📦 Creating DMG volume…"
	rm -f "$(BUILD_DIR)/$(APP_NAME).dmg"
	hdiutil create -ov -volname "$(APP_NAME)" -srcfolder "$(BUILD_DIR)/dmg_stage" -format UDZO "$(BUILD_DIR)/$(APP_NAME).dmg"
	rm -rf "$(BUILD_DIR)/dmg_stage"
	@echo "✅ DMG packaging complete → $(BUILD_DIR)/$(APP_NAME).dmg"

# ── Clean ────────────────────────────────────────────────────
clean:
	@echo "🧹 Cleaning…"
	swift package clean
	rm -rf "$(APP_BUNDLE)" "$(BUILD_DIR)/$(APP_NAME).dmg"
	@echo "✅ Clean."

# ── Help ─────────────────────────────────────────────────────
help:
	@echo ""
	@echo "Signal Makefile targets:"
	@echo "  make build     – Build release binary & .app bundle"
	@echo "  make run       – Build and launch the app"
	@echo "  make install   – Copy .app to /Applications, CLI to ~/.local/bin"
	@echo "  make dmg       – Package .app and CLI into .dmg"
	@echo "  make uninstall – Remove installed files"
	@echo "  make clean     – Remove build artifacts"
	@echo "  make help      – Show this help"
	@echo ""
