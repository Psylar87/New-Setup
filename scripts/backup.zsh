#!/usr/bin/env zsh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WALLPAPER_BACKUP_DIR="${SCRIPT_DIR}"
TIMESTAMP_FILE="${SCRIPT_DIR}/last_wallpaper_change.txt"

HOMEBREW_PATH="/opt/homebrew/bin"
HOMEBREW_SBIN="/opt/homebrew/sbin"
export PATH="$HOMEBREW_PATH:$HOMEBREW_SBIN:$PATH"

echo "Current user: $(whoami)"
echo "Script started at $(date)"

cd "$SCRIPT_DIR"

if [ ! -f "$TIMESTAMP_FILE" ]; then
    touch "$TIMESTAMP_FILE"
    echo "0" > "$TIMESTAMP_FILE"
    git add "$TIMESTAMP_FILE"
    git commit -m "Create timestamp file for wallpaper changes"
fi

last_change_timestamp=$(cat "$TIMESTAMP_FILE")
wallpaper_path=$(osascript -e 'tell application "System Events" to get picture of current desktop' 2>/dev/null || echo "")

if [ -z "$wallpaper_path" ]; then
    echo "No wallpaper change detected."
else
    echo "Wallpaper path: $wallpaper_path"
    current_timestamp=$(stat -f "%m" "$wallpaper_path" 2>/dev/null || echo "0")

    if [ "$last_change_timestamp" != "$current_timestamp" ]; then
        cp "$wallpaper_path" "$WALLPAPER_BACKUP_DIR" || { echo "Failed to copy wallpaper"; exit 1; }
        new_wallpaper_path="${WALLPAPER_BACKUP_DIR}/Desktop.png"
        mv "${WALLPAPER_BACKUP_DIR}/$(basename "$wallpaper_path")" "$new_wallpaper_path" || { echo "Failed to rename wallpaper"; exit 1; }
        echo "$current_timestamp" > "$TIMESTAMP_FILE"
        git add "$new_wallpaper_path"
    fi
fi

echo "Running brew doctor..."
brew doctor || true

echo "Updating Homebrew..."
brew update
brew upgrade && brew upgrade --cask
brew cleanup --prune=all

echo "Updating Spicetify..."
spicetify update || true

echo "Dumping Brewfile..."
brew bundle dump --describe --force --file="${SCRIPT_DIR}/Brewfile"

echo "Running Mackup backup..."
mackup backup --force
mackup uninstall --force

if git status --porcelain | grep .; then
    git add .
    git commit -m "chore(backup): Auto update"
    git push
else
    echo "No changes to commit"
fi

echo "Backup complete!"
