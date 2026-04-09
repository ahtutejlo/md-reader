PREFIX ?= /usr/local
APP_DIR ?= /Applications

build:
	swift build -c release

bundle: build
	CONFIG=release ./scripts/bundle.sh

install-app: bundle
	rm -rf $(APP_DIR)/MDReader.app
	cp -R .build/MDReader.app $(APP_DIR)/MDReader.app
	codesign --force --deep --sign - $(APP_DIR)/MDReader.app
	xattr -dr com.apple.quarantine $(APP_DIR)/MDReader.app 2>/dev/null || true
	touch $(APP_DIR)/MDReader.app
	/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
		-f $(APP_DIR)/MDReader.app

install-cli: build
	install -d $(PREFIX)/bin
	install .build/release/mdreader $(PREFIX)/bin/mdreader

install: install-app install-cli

uninstall:
	rm -f $(PREFIX)/bin/mdreader
	rm -rf $(APP_DIR)/MDReader.app

.PHONY: build bundle install install-app install-cli uninstall
