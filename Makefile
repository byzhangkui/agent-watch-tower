# Agent Watch Tower - macOS Menu Bar App
# Build system for creating .app bundles from Swift Package Manager

APP_NAME     := AgentWatchTower
DISPLAY_NAME := Agent Watch Tower
BUNDLE_ID    := com.agentwatchtower.app
VERSION      := 0.1.0

# Paths
BUILD_DIR    := .build
RELEASE_BIN  := $(BUILD_DIR)/release/$(APP_NAME)
DEBUG_BIN    := $(BUILD_DIR)/debug/$(APP_NAME)
BUNDLE_DIR   := $(BUILD_DIR)/$(APP_NAME).app
INSTALL_DIR  := /Applications

# .app bundle internal structure
CONTENTS     := $(BUNDLE_DIR)/Contents
MACOS_DIR    := $(CONTENTS)/MacOS
RES_DIR      := $(CONTENTS)/Resources

# ─── Default ────────────────────────────────────────────────────

.PHONY: all
all: build  ## Build debug binary (default)

# ─── Build ──────────────────────────────────────────────────────

.PHONY: build
build:  ## Build debug binary
	swift build

.PHONY: release
release:  ## Build release (optimized) binary
	swift build -c release

# ─── Bundle ─────────────────────────────────────────────────────

.PHONY: bundle
bundle: release  ## Build release and assemble .app bundle
	@echo "==> Assembling $(APP_NAME).app ..."
	@rm -rf $(BUNDLE_DIR)
	@mkdir -p $(MACOS_DIR) $(RES_DIR)
	@# Copy executable
	@cp $(RELEASE_BIN) $(MACOS_DIR)/$(APP_NAME)
	@# Copy Info.plist
	@cp Resources/Info.plist $(CONTENTS)/Info.plist
	@# Copy entitlements (kept alongside for codesign reference)
	@cp Resources/AgentWatchTower.entitlements $(RES_DIR)/
	@# Copy icon if exists
	@if [ -f Resources/AppIcon.icns ]; then \
		cp Resources/AppIcon.icns $(RES_DIR)/AppIcon.icns; \
	fi
	@echo "==> $(BUNDLE_DIR) ready"

# ─── Code Signing ──────────────────────────────────────────────

.PHONY: sign
sign: bundle  ## Code-sign the .app bundle (ad-hoc)
	codesign --force --deep --sign - \
		--entitlements Resources/AgentWatchTower.entitlements \
		$(BUNDLE_DIR)
	@echo "==> Signed (ad-hoc)"

.PHONY: sign-dev
sign-dev: bundle  ## Code-sign with Apple Development identity
	codesign --force --deep \
		--sign "Apple Development" \
		--entitlements Resources/AgentWatchTower.entitlements \
		$(BUNDLE_DIR)
	@echo "==> Signed (Apple Development)"

# ─── Install ───────────────────────────────────────────────────

.PHONY: install
install: bundle sign  ## Install .app to /Applications
	@echo "==> Installing to $(INSTALL_DIR) ..."
	@rm -rf $(INSTALL_DIR)/$(APP_NAME).app
	@cp -R $(BUNDLE_DIR) $(INSTALL_DIR)/$(APP_NAME).app
	@echo "==> Installed at $(INSTALL_DIR)/$(APP_NAME).app"

# ─── Run ────────────────────────────────────────────────────────

.PHONY: run
run: build  ## Build debug and run directly
	$(DEBUG_BIN)

.PHONY: run-release
run-release: bundle  ## Build release .app and open it
	open $(BUNDLE_DIR)

# ─── Hooks ──────────────────────────────────────────────────────

.PHONY: hooks-install
hooks-install: build  ## Register Claude Code HTTP hooks in ~/.claude/settings.json
	@echo "==> Installing Claude Code hooks ..."
	@$(DEBUG_BIN) --install-hooks 2>/dev/null || \
		echo "Run the app and use Settings > Agents > Install Hooks"

.PHONY: hooks-check
hooks-check:  ## Check if hooks are registered
	@if grep -q "localhost:19280" ~/.claude/settings.json 2>/dev/null; then \
		echo "Hooks: installed"; \
	else \
		echo "Hooks: not installed"; \
	fi

# ─── Test ───────────────────────────────────────────────────────

.PHONY: test
test:  ## Run tests
	swift test

# ─── Lint ───────────────────────────────────────────────────────

.PHONY: lint
lint:  ## Run SwiftLint (if installed)
	@if command -v swiftlint >/dev/null 2>&1; then \
		swiftlint; \
	else \
		echo "swiftlint not found, skipping"; \
	fi

.PHONY: format
format:  ## Run swift-format (if installed)
	@if command -v swift-format >/dev/null 2>&1; then \
		swift-format format -i -r Sources/ Tests/; \
	else \
		echo "swift-format not found, skipping"; \
	fi

# ─── Clean ──────────────────────────────────────────────────────

.PHONY: clean
clean:  ## Remove build artifacts
	swift package clean
	rm -rf $(BUILD_DIR)

# ─── Dependencies ──────────────────────────────────────────────

.PHONY: resolve
resolve:  ## Resolve SPM dependencies
	swift package resolve

.PHONY: update
update:  ## Update SPM dependencies
	swift package update

# ─── Help ───────────────────────────────────────────────────────

.PHONY: help
help:  ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'
