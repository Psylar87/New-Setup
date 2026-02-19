#!/usr/bin/env zsh

set -euo pipefail

echo "Starting dock setup..."

defaults write com.apple.dock "tilesize" -int 40
defaults write com.apple.dock "show-recents" -bool false

if ! command -v brew &> /dev/null; then
    echo "Homebrew is not installed. Please install Homebrew first."
    exit 1
fi

if ! command -v dockutil &> /dev/null; then
    echo "dockutil not found. Installing via Homebrew..."
    brew install dockutil || { echo "Failed to install dockutil"; exit 1; }
    echo "dockutil installed."
fi

typeset -a dock_items=(
    "/Applications/Zen Browser.app:1"
    "/Applications/Spotify.app:2"
    "/System/Applications/Messages.app:3"
    "/Applications/Messenger.app:4"
    "/Applications/Signal.app:5"
    "/Applications/Proton Mail.app:6"
    "/Applications/Zed.app:7"
)

dockutil --remove all --no-restart

for item in "${dock_items[@]}"; do
    IFS=":" read -r app_path position <<< "$item"
    if [[ -d "$app_path" ]]; then
        echo "Adding $app_path at position $position"
        dockutil --add "$app_path" --position "$position" --no-restart || { echo "Warning: Failed to add $app_path"; }
    else
        echo "Warning: $app_path not found, skipping..."
    fi
done

downloads_path="$HOME/Downloads"
echo "Adding Downloads folder as folder icon"
dockutil --add "$downloads_path" --display folder --allhomes --no-restart || { echo "Failed to add Downloads folder"; exit 1; }

echo "Restarting Dock..."
killall Dock

echo "Dock setup complete."
