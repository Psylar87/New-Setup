#!/usr/bin/env zsh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WALLPAPER_BACKUP_DIR="${SCRIPT_DIR}"
TIMESTAMP_FILE="${SCRIPT_DIR}/last_wallpaper_change.txt"
BACKUP_BRANCH="${BACKUP_BRANCH:-main}"
REQUIRE_BACKUP_BRANCH="${REQUIRE_BACKUP_BRANCH:-true}"
AUTO_PUSH="${AUTO_PUSH:-true}"

HOMEBREW_PATH="/opt/homebrew/bin"
HOMEBREW_SBIN="/opt/homebrew/sbin"
export PATH="$HOMEBREW_PATH:$HOMEBREW_SBIN:$PATH"

echo "Current user: $(whoami)"
echo "Script started at $(date)"

cd "$SCRIPT_DIR"

if [[ ! -f "$TIMESTAMP_FILE" ]]; then
    touch "$TIMESTAMP_FILE"
    echo "0" > "$TIMESTAMP_FILE"
fi

last_change_timestamp=$(cat "$TIMESTAMP_FILE")
wallpaper_path=$(osascript -e 'tell application "System Events" to get picture of current desktop' 2>/dev/null || echo "")

if [[ -z "$wallpaper_path" ]]; then
    echo "No wallpaper change detected."
else
    echo "Wallpaper path: $wallpaper_path"
    current_timestamp=$(stat -f "%m" "$wallpaper_path" 2>/dev/null || echo "0")

    if [[ "$last_change_timestamp" != "$current_timestamp" ]]; then
        if [[ "$wallpaper_path" == "${WALLPAPER_BACKUP_DIR}/Desktop.png" ]]; then
            echo "Wallpaper already backed up, skipping..."
        else
            new_wallpaper_path="${WALLPAPER_BACKUP_DIR}/Desktop.png"
            cp "$wallpaper_path" "$new_wallpaper_path" || { echo "Failed to copy wallpaper"; exit 1; }
            echo "$current_timestamp" > "$TIMESTAMP_FILE"
        fi
    fi
fi

echo "Running brew doctor..."
brew doctor || true

echo "Updating Homebrew..."
brew update || true
brew upgrade || true
brew upgrade --cask || true
brew cleanup --prune=all || true

echo "Updating Spicetify..."
spicetify update || true

echo "Dumping Brewfile..."
brew bundle dump --describe --force --file="${SCRIPT_DIR}/Brewfile.tmp" 2>/dev/null || true
grep -v "^mas " "${SCRIPT_DIR}/Brewfile.tmp" | grep -v "^vscode " > "${SCRIPT_DIR}/Brewfile" || true
rm -f "${SCRIPT_DIR}/Brewfile.tmp"

brew bundle dump --describe --force --mas --file="${SCRIPT_DIR}/Brewfile.mas.tmp" 2>/dev/null || true
grep "^mas " "${SCRIPT_DIR}/Brewfile.mas.tmp" > "${SCRIPT_DIR}/Brewfile.mas" || true
rm -f "${SCRIPT_DIR}/Brewfile.mas.tmp"

echo "Running Mackup backup..."
mackup backup --force || true
mackup uninstall --force || true

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")

    if [[ "$REQUIRE_BACKUP_BRANCH" == "true" ]] && [[ "$current_branch" != "$BACKUP_BRANCH" ]]; then
        echo "Skipping git commit/push: current branch '$current_branch' is not backup branch '$BACKUP_BRANCH'"
    else
        typeset -a managed_files=(
            "$TIMESTAMP_FILE"
            "${SCRIPT_DIR}/Desktop.png"
            "${SCRIPT_DIR}/Brewfile"
            "${SCRIPT_DIR}/Brewfile.mas"
            "${SCRIPT_DIR}/scripts/backup.zsh"
            "${SCRIPT_DIR}/scripts/setup.zsh"
            "${SCRIPT_DIR}/scripts/dock.zsh"
            "${SCRIPT_DIR}/scripts/.gitignore"
        )

        for managed_file in "${managed_files[@]}"; do
            if [[ -f "$managed_file" ]]; then
                git add "$managed_file"
            fi
        done

        if ! git diff --cached --quiet; then
            git commit -m "chore(backup): Auto update"
        else
            echo "No managed backup files changed"
        fi

        if [[ "$AUTO_PUSH" == "true" ]]; then
            if git rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
                git push
            else
                echo "No upstream configured; skipping push"
            fi
        else
            echo "AUTO_PUSH is false; skipping push"
        fi
    fi
else
    echo "Not inside a git repository; skipping commit and push"
fi

echo "Backup complete!"
