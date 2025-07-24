#!/bin/bash
# =============================================================================
# Script: install_s3cmd.sh
# Purpose: Installs the s3cmd package using the apt package manager.
# Copyright: (c) 2025 Alejandro Capuro Meyer. All rights reserved.
# License: GPL v3 - see LICENSE file for details
# Development: This script was developed with AI assistance (including Gemini,
#              ChatGPT, Claude, Jules, Firebase, and others) under human
#              guidance for architecture, logic design, and project direction.
# File Version: 20250723.154700
# Project Repository: https://github.com/capuromeyer/db_backups
# Usage: This script is intended to be called by other scripts (e.g., an installer)
#        and is not meant for direct execution.
#
# Notes:
# - This script is idempotent; it first checks if s3cmd is already installed
#   and will exit if it is.
# - Requires sudo privileges for apt install commands.
# =============================================================================

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
