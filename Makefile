APP_NAME    = Imperator MenuBarFolders
BINARY_NAME = MenuBarFolders
BUNDLE      = build/$(APP_NAME).app
DIST        = dist
ZIP         = $(DIST)/Imperator-MenuBarFolders-$(VERSION).zip
BUILD_NUMBER = $(shell git rev-list --count HEAD)

# Self-signed identity, not ad-hoc. The app registers a login item through
# SMAppService, and that registration is keyed to the bundle's designated
# requirement. Ad-hoc signing mints a new cdhash on every build, so every
# update would look like a different app and drop the login item. The
# Imperator Dev cert keeps the requirement stable across releases.
CODESIGN_IDENTITY ?= Imperator Dev

# AppKit picks which generation of a control to draw from the sdk field in the
# binary's LC_BUILD_VERSION, and SwiftPM stamps that field from platforms: in
# Package.swift rather than from the SDK it compiled against. Left alone this app
# reports sdk 14.0 and draws macOS 14 era switches on macOS 27. Raising platforms:
# would fix the stamp but make macOS 27 the minimum, which a public repo promising
# macOS 14 cannot do, so the stamp is set here instead: minos stays 14.0, sdk
# follows whatever SDK is installed.
DEPLOYMENT_TARGET = 14.0
SDK_VERSION = $(shell xcrun --sdk macosx --show-sdk-version)
PLATFORM_FLAGS = -Xlinker -platform_version -Xlinker macos \
                 -Xlinker $(DEPLOYMENT_TARGET) -Xlinker $(SDK_VERSION)

.PHONY: all build clean run install dist release check-version

all: build

build:
	swift build -c release $(PLATFORM_FLAGS)
	@rm -rf "$(BUNDLE)"
	@mkdir -p "$(BUNDLE)/Contents/MacOS" "$(BUNDLE)/Contents/Resources"
	cp ".build/release/$(BINARY_NAME)" "$(BUNDLE)/Contents/MacOS/$(BINARY_NAME)"
	cp Resources/Info.plist "$(BUNDLE)/Contents/Info.plist"
	cp Resources/AppIcon.icns "$(BUNDLE)/Contents/Resources/AppIcon.icns"
	codesign --force --sign "$(CODESIGN_IDENTITY)" "$(BUNDLE)"
	@echo "Built: $(BUNDLE)"

install: build
	@pkill -x $(BINARY_NAME) 2>/dev/null || true
	@sleep 0.5
	rm -rf "/Applications/$(APP_NAME).app"
	cp -R "$(BUNDLE)" "/Applications/$(APP_NAME).app"
	@echo "Installed: /Applications/$(APP_NAME).app"
	open "/Applications/$(APP_NAME).app"

run: build
	open "$(BUNDLE)"

clean:
	rm -rf build dist

check-version:
	@test -n "$(VERSION)" || { echo "Usage: make $(MAKECMDGOALS) VERSION=1.0.0"; exit 1; }

# Build a distributable zip. Safe -- touches nothing in git, nothing on the remote.
dist: check-version build
	@mkdir -p $(DIST)
	rm -f "$(ZIP)"
	# Stamp the version into the BUILT bundle, not the source, so a test zip
	# reports the version it will ship as without dirtying the working tree.
	# Editing Info.plist breaks the signature, so re-sign after.
	/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $(VERSION)" "$(BUNDLE)/Contents/Info.plist"
	/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $(BUILD_NUMBER)" "$(BUNDLE)/Contents/Info.plist"
	codesign --force --sign "$(CODESIGN_IDENTITY)" "$(BUNDLE)"
	ditto -c -k --sequesterRsrc --keepParent "$(BUNDLE)" "$(ZIP)"
	@echo "Packaged: $(ZIP)"

# Bump version, commit, tag, push, publish the GitHub release with the zip attached.
release: check-version
	@git diff --quiet && git diff --cached --quiet || { echo "Working tree dirty -- commit first."; exit 1; }
	/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $(VERSION)" Resources/Info.plist
	/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $(BUILD_NUMBER)" Resources/Info.plist
	$(MAKE) dist VERSION=$(VERSION)
	git add Resources/Info.plist
	git commit -m "Release v$(VERSION)"
	git tag -a v$(VERSION) -m "$(APP_NAME) $(VERSION)"
	git push origin HEAD
	git push origin v$(VERSION)
	gh release create v$(VERSION) \
		--title "$(APP_NAME) $(VERSION)" \
		--notes "Group your apps into folders that live in the macOS menu bar. Each folder is its own menu bar icon; click it and a panel drops down with the apps inside. Pick from 138 built-in Lucide icons or paste your own SVG. Signed with a self-signed certificate and not notarized, so Gatekeeper blocks the first launch: right-click the app and choose Open, or run \`xattr -dr com.apple.quarantine \"/Applications/$(APP_NAME).app\"\`." \
		"$(ZIP)#$(APP_NAME) $(VERSION) (macOS)"
	@echo "Released v$(VERSION)"
