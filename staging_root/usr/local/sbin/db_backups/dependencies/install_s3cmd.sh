#!/bin/bash
# -----------------------------------------------------------------------------
# Script: install_s3cmd.sh
# Purpose: Installs s3cmd package using apt.
# Author: Alejandro Capuro (Original tool concept) / Jules (Script generation)
# Copyright: (c) $(date +%Y) Alejandro Capuro. All rights reserved.
# Version: 0.1.0
#
# Notes:
#   - Requires sudo for apt install commands.
#   - Idempotent: checks if s3cmd is already installed.
# -----------------------------------------------------------------------------

set -e

# Function to check if a package (command) is installed
is_installed() {
    command -v "$1" &> /dev/null
}

echo "--- s3cmd Installer ---"
echo "Checking s3cmd status..."
if is_installed s3cmd; then
    echo "s3cmd is already installed."
else
    echo "s3cmd not found. Attempting to install..."
    echo "Running sudo apt update (this may take a moment)..."
    sudo apt update
    echo "Installing s3cmd via apt..."
    if sudo apt install -y s3cmd; then
        if is_installed s3cmd; then
            echo "s3cmd installed successfully."
        else
            echo "[ERROR] 'apt install s3cmd' reported success, but command 's3cmd' is still not found." >&2
            exit 1
        fi
    else
        echo "[ERROR] Failed to install s3cmd using apt. Please check messages above." >&2
        exit 1
    fi
fi
echo ""
echo "s3cmd check/installation complete."
exit 0
