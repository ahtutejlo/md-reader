---
name: install
description: Build and install MDReader app to /Applications and CLI to /usr/local/bin
---

Build and install MDReader (app + CLI) using the steps below. Execute each step sequentially, stopping on any failure.

## Step 1: Build release

Run `swift build -c release` from the project root.

## Step 2: Create .app bundle

Create the MDReader.app bundle structure in `.build/MDReader.app`:

```
.build/MDReader.app/
└── Contents/
    ├── Info.plist
    ├── MacOS/
    │   └── MDReader
    └── Resources/
        └── AppIcon.icns
```

1. Remove any existing `.build/MDReader.app` directory
2. Create directories: `Contents/MacOS` and `Contents/Resources`
3. Copy the release binary: `.build/release/MDReaderApp` → `Contents/MacOS/MDReader`
4. Copy the icon: `Sources/MDReaderApp/Resources/AppIcon.icns` → `Contents/Resources/`
5. Write `Contents/Info.plist` using the template from `scripts/bundle.sh`

## Step 3: Install app to /Applications

Copy `.build/MDReader.app` to `/Applications/MDReader.app`, replacing the existing version if present:

```bash
rm -rf /Applications/MDReader.app
cp -R .build/MDReader.app /Applications/MDReader.app
```

## Step 4: Install CLI

```bash
sudo install -d /usr/local/bin
sudo install .build/release/mdreader /usr/local/bin/mdreader
```

## Step 5: Verify

1. Run `ls -la /Applications/MDReader.app/Contents/MacOS/MDReader` to confirm the app is installed
2. Run `which mdreader` to confirm the CLI is in PATH
3. Report the result to the user
