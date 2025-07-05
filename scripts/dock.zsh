#!/usr/bin/env zsh

set -euo pipefail

echo "Starting dock setup..."

# Set dock size and recent apps setting
defaults write com.apple.dock "tilesize" -int 40
defaults write com.apple.dock "show-recents" -bool false

# Check for Homebrew first
if ! command -v brew &> /dev/null; then
  echo "Homebrew is not installed. Please install Homebrew first."
  exit 1
fi

# Check for dockutil and install if missing
if ! command -v dockutil &> /dev/null; then
  echo "dockutil not found. Installing via Homebrew..."
  brew install dockutil || { echo "Failed to install dockutil"; exit 1; }
  echo "dockutil installed."
fi

# Define apps and their positions in an array of tuples
typeset -a dock_items=(
  "/Applications/Zen Browser.app:1"
  "/Applications/Spotify.app:2"
  "/System/Applications/Messages.app:3"
  "/Applications/Messenger.app:4"
  "/Applications/Signal.app:5"
  "/Applications/Proton Mail.app:6"
  "/Applications/Zed.app:7"
)

# Remove all existing dock items without restarting dock yet
dockutil --remove all --no-restart

# Add apps to dock
for item in "${dock_items[@]}"; do
  IFS=":" read -r app_path position <<< "$item"
  echo "Adding $app_path at position $position"
  dockutil --add "$app_path" --position "$position" --no-restart || { echo "Failed to add $app_path"; exit 1; }
done

# Add Downloads folder as a folder icon (not a stack)
downloads_path="$HOME/Downloads"
echo "Adding Downloads folder as folder icon"
dockutil --add "$downloads_path" --display folder --allhomes --no-restart || { echo "Failed to add Downloads folder"; exit 1; }

# Restart dock to apply changes
echo "Restarting Dock..."
killall Dock

echo "Dock setup complete."
