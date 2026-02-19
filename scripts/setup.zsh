#!/usr/bin/env zsh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

get_brew_path() {
    if [[ -f "/opt/homebrew/bin/brew" ]]; then
        echo "/opt/homebrew/bin/brew"
    elif [[ -f "/usr/local/bin/brew" ]]; then
        echo "/usr/local/bin/brew"
    else
        echo ""
    fi
}

if ! command -v brew &> /dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    BREW_PATH=$(get_brew_path)
    if [[ -n "$BREW_PATH" ]]; then
        echo "Adding Homebrew to shell configuration..."
        echo "eval \"\$($BREW_PATH shellenv)\"" >> ~/.zshrc
        eval "$($BREW_PATH shellenv)"
    else
        echo "Error: Could not locate Homebrew after installation"
        exit 1
    fi
else
    echo "Homebrew is already installed"
fi

BREWFILE_PATH="${SCRIPT_DIR}/Brewfile"
if [[ -f "$BREWFILE_PATH" ]]; then
    echo "Installing applications from Brewfile..."
    brew bundle --file "$BREWFILE_PATH"
else
    echo "Warning: Brewfile not found at $BREWFILE_PATH, skipping..."
fi

echo ""
echo "Would you like to configure Mackup for syncing application settings? (y/n): "
read MACKUP_REPLY
echo ""

if [[ $MACKUP_REPLY =~ ^[Yy]es$ ]] || [[ $MACKUP_REPLY =~ ^[Yy]$ ]]; then
    MACKUP_CONFIG_PATH="$HOME/.mackup.cfg"
    
    echo "Select Mackup storage engine:"
    echo "  1) iCloud (requires iCloud to be configured)"
    echo "  2) Dropbox"
    echo "  3) Google Drive"
    echo "  4) Skip Mackup setup"
    echo ""
    echo "Enter choice (1-4): "
    read MACKUP_ENGINE
    echo ""
    
    case $MACKUP_ENGINE in
        1)
            echo "[storage]" > "$MACKUP_CONFIG_PATH"
            echo "engine = icloud" >> "$MACKUP_CONFIG_PATH"
            ;;
        2)
            echo "[storage]" > "$MACKUP_CONFIG_PATH"
            echo "engine = dropbox" >> "$MACKUP_CONFIG_PATH"
            ;;
        3)
            echo "[storage]" > "$MACKUP_CONFIG_PATH"
            echo "engine = google_drive" >> "$MACKUP_CONFIG_PATH"
            ;;
        4)
            echo "Skipping Mackup setup"
            ;;
        *)
            echo "Invalid choice, skipping Mackup setup"
            ;;
    esac
    
    if [[ $MACKUP_ENGINE =~ ^[1-3]$ ]]; then
        echo "Restoring Mackup settings..."
        mackup restore --force || echo "Warning: Mackup restore failed"
        mackup uninstall --force || echo "Warning: Mackup uninstall failed"
    fi
else
    echo "Skipping Mackup setup"
fi

echo "Customizing macOS defaults..."
osascript -e 'tell application "System Events" to tell appearance preferences to set dark mode to true' 2>/dev/null || echo "Warning: Could not set dark mode"
defaults write NSGlobalDomain com.apple.swipescrolldirection -bool false
defaults write NSGlobalDomain com.apple.mouse.scaling -float "2.5"
defaults write com.apple.AppleMultitouchTrackpad "FirstClickThreshold" -int "0" 2>/dev/null || true
defaults write com.apple.finder "ShowPathbar" -bool "true"
defaults write com.apple.finder "FXDefaultSearchScope" -string "SCcf"
defaults write NSGlobalDomain "NSTableViewDefaultSizeMode" -int "3"
defaults write com.apple.finder "ShowHardDrivesOnDesktop" -bool "true"
defaults write com.apple.finder FXArrangeGroupViewBy -string Kind
killall Finder 2>/dev/null || true

DOCK_SCRIPT="${SCRIPT_DIR}/scripts/dock.zsh"
if [[ -f "$DOCK_SCRIPT" ]]; then
    echo "Setting up the dock..."
    "$DOCK_SCRIPT"
else
    echo "Warning: Dock script not found at $DOCK_SCRIPT"
fi

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
    echo "Warning: Wallpaper not found at $IMAGE_PATH, skipping..."
fi

echo ""
echo "Checking for Touch ID capability..."
if [[ -f "/usr/lib/pam/pam_tid.so" ]] && system_profiler SPiBridgeDataType 2>/dev/null | grep -q "Apple"; then
    echo "This Mac appears to have Touch ID capability."
    SUDO_PATH="/private/etc/pam.d/sudo"
    echo "Enable Touch ID for sudo in terminal? (y/n): "
    read REPLY
    echo ""
    
    if [[ $REPLY =~ ^[Yy]es$ ]] || [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Enabling Touch ID for sudo in terminal"
        echo "A backup of the original file will be created at $SUDO_PATH.bak"
        sudo sed -i.bak '2s;^;auth       sufficient    pam_tid.so\n;' "$SUDO_PATH" || echo "Warning: Failed to configure Touch ID for sudo"
        echo "Touch ID for sudo in terminal enabled"
    else
        echo "Touch ID for sudo in terminal was not enabled"
    fi
else
    echo "Touch ID not available on this Mac, skipping sudo configuration..."
fi

echo ""
echo "Setup complete!"
