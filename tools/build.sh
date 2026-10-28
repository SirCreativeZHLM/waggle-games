#!/bin/sh
# Export macOS, Windows and Linux builds with Godot (needs Godot export templates installed:
# Editor > Manage Export Templates). Builds natively on this machine; no VM.
set -e
cd "$(dirname "$0")/../game"
mkdir -p ../build
godot --headless --export-release "macOS" ../build/WaggleGames-mac.zip
godot --headless --export-release "Windows" ../build/WaggleGames-windows.exe
godot --headless --export-release "Linux" ../build/WaggleGames-linux.x86_64
