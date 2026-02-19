#!/usr/bin/env zsh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

if ! command -v brew &> /dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zshrc
    eval "$(/opt/homebrew/bin/brew shellenv)"
else
    echo "Homebrew is already installed"
fi

echo "Installing applications from Brewfile..."
brew bundle --file "${SCRIPT_DIR}/Brewfile"

echo "Configuring Mackup..."
MACKUP_CONFIG_PATH="$HOME/.mackup.cfg"

echo "[storage]" > "$MACKUP_CONFIG_PATH"
echo "engine = icloud" >> "$MACKUP_CONFIG_PATH"

echo "Restoring Mackup settings..."
mackup restore --force
mackup uninstall --force

echo "Customizing macOS defaults..."
osascript -e 'tell application "System Events" to tell appearance preferences to set dark mode to true'
defaults write NSGlobalDomain com.apple.swipescrolldirection -bool false
defaults write NSGlobalDomain com.apple.mouse.scaling -float "2.5"
defaults write com.apple.AppleMultitouchTrackpad "FirstClickThreshold" -int "0"
defaults write com.apple.finder "ShowPathbar" -bool "true"
defaults write com.apple.finder "FXDefaultSearchScope" -string "SCcf"
defaults write NSGlobalDomain "NSTableViewDefaultSizeMode" -int "3"
defaults write com.apple.finder "ShowHardDrivesOnDesktop" -bool "true"
defaults write com.apple.finder FXArrangeGroupViewBy -string Kind
killall Finder

echo "Setting up the dock..."
"${SCRIPT_DIR}/scripts/dock.zsh"

echo "Setting desktop wallpaper..."
IMAGE_PATH="${SCRIPT_DIR}/Desktop.png"

if [[ -f "$IMAGE_PATH" ]]; then
    osascript <<EOF
tell application "System Events"
    set desktopCount to count of desktops
    repeat with desktopNumber from 1 to desktopCount
        tell desktop desktopNumber
            set picture to "$IMAGE_PATH"
        end tell
    end repeat
end tell
EOF
else
    echo "Warning: Wallpaper not found at $IMAGE_PATH"
fi

echo "Configuring Touch ID for sudo..."
SUDO_PATH="/private/etc/pam.d/sudo"
echo "Enable touch id for sudo in terminal? (y/n): "
read REPLY
echo ""

if [[ $REPLY =~ ^[Yy]es$ ]] || [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Enabling touch id for sudo in terminal"
    echo "A backup of the original file will be created at $SUDO_PATH.bak"
    sudo sed -i.bak '2s;^;auth       sufficient    pam_tid.so\n;' "$SUDO_PATH"
    echo "Touch id for sudo in terminal enabled"
else
    echo "Touch id for sudo in terminal was not enabled"
fi

echo "Setup complete!"
