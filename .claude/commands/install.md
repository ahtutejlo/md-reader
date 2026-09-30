---
name: install
description: Build and install MDReader app to /Applications and CLI to /usr/local/bin
---

Build and install MDReader (app + CLI) using the steps below. Execute each step sequentially, stopping on any failure.

## Step 1: Build and install the app

Run `make install-app` from the project root. It builds a release `.app` with `scripts/bundle.sh`, copies it to `/Applications`, signs it and registers it with Launch Services.

## Step 2: Install CLI

```bash
sudo install -d /usr/local/bin
sudo install .build/release/mdreader /usr/local/bin/mdreader
```

## Step 3: Verify

1. Run `ls -la /Applications/MDReader.app/Contents/MacOS/MDReader` to confirm the app is installed
2. Run `which mdreader` to confirm the CLI is in PATH
3. Report the result to the user
