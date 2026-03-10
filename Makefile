PREFIX ?= /usr/local

build:
	swift build -c release

install: build
	install -d $(PREFIX)/bin
	install .build/release/mdreader $(PREFIX)/bin/mdreader

uninstall:
	rm -f $(PREFIX)/bin/mdreader

.PHONY: build install uninstall
