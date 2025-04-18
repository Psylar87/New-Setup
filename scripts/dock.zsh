#!/bin/zsh

# Script to manage the dock on macOS using defaults & dockutil
# https://github.com/kcrawford/dockutil

# set dock size
defaults write com.apple.dock "tilesize" -int "40"
# set show recent apps
defaults write com.apple.dock "show-recents" -bool "false"

# check if dockutil is installed
# this should be installed via homebrew during 
# the setup-machine script. Which will also call this script.
if ! command -v dockutil &> /dev/null
then
    echo "dockutil could not be found"
    # Install dockutil
    if command -v brew &> /dev/null
    then
        brew install dockutil
        echo "dockutil installed"
    else
        echo "Homebrew is not installed. Please install Homebrew first."
        exit 1
    fi
fi

# Setup dock
# this will remove all dock items and prevent Killall Dock
dockutil --remove all --no-restart
# Start adding items
dockutil --add  /Applications/Zen\ Browser.app --position 1 --no-restart
dockutil --add  /Applications/Spotify.app --position 2 --no-restart
dockutil --add  /System/Applications/Messages.app --position 3 --no-restart
dockutil --add  /Applications/Messenger.app --position 4 --no-restart
dockutil --add  /Applications/Signal.app --position 5 --no-restart
dockutil --add  /Applications/Proton\ Mail.app --position 6 --no-restart
dockutil --add  /Applications/Zed.app --position 7 --no-restart

# Add folder/directory as stack
dockutil --add '~/Downloads' --view grid --display folder --allhomes --no-restart

# Restart dock to apply changes
killall Dock
