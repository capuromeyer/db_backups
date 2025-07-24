#!/bin/bash
# =============================================================================
# Script: install_base_utils.sh
# Purpose: Installs basic utility packages (zip, bc, sqlite3, git) using the apt
#          package manager. The script is designed to be called with a specific
#          package name as an argument.
# Copyright: (c) 2025 Alejandro Capuro Meyer. All rights reserved.
# License: GPL v3 - see LICENSE file for details
# Development: This script was developed with AI assistance (including Gemini,
#              ChatGPT, Claude, Jules, Firebase, and others) under human
#              guidance for architecture, logic design, and project direction.
# File Version: 20250723.154600
# Project Repository: https://github.com/capuromeyer/db_backups
# Usage: sudo ./install_base_utils.sh <package_name>
#   Example: sudo ./install_base_utils.sh zip
#
# Notes:
# - This script is idempotent; it checks if the package's command is already
#   installed and will exit if it is.
# - Requires sudo privileges for apt install commands.
# =============================================================================

set -e

# Function to check if a command (and thus typically its package) is installed
is_installed() {
    command -v "$1" &> /dev/null
}

# This script now expects one argument: the package/command to install (e.g., "zip" or "bc")
PACKAGE_TO_INSTALL="$1"

if [ -z "$PACKAGE_TO_INSTALL" ]; then
    echo "[ERROR] No package specified for install_base_utils.sh. Usage: $0 <package_name (zip|bc|sqlite3|git)>" >&2
    exit 1
fi

echo "--- Base Utility Installer for '$PACKAGE_TO_INSTALL' ---"

NEEDS_INSTALL=false
CMD_TO_CHECK=""
ACTUAL_PACKAGE_NAME="" # Package name for apt might differ from command, though usually same for these

case "$PACKAGE_TO_INSTALL" in
    zip)
        CMD_TO_CHECK="zip"
        ACTUAL_PACKAGE_NAME="zip"
        ;;
    bc)
        CMD_TO_CHECK="bc"
        ACTUAL_PACKAGE_NAME="bc"
        ;;
    sqlite3)
        CMD_TO_CHECK="sqlite3"
        ACTUAL_PACKAGE_NAME="sqlite3"
        ;;
    git)
        CMD_TO_CHECK="git"
        ACTUAL_PACKAGE_NAME="git"
        ;;
    *)
        echo "[ERROR] Unsupported package specified: '$PACKAGE_TO_INSTALL'. Supported options are 'zip', 'bc', 'sqlite3', 'git'." >&2
        exit 1
        ;;
esac

if is_installed "$CMD_TO_CHECK"; then
    echo "Package '$PACKAGE_TO_INSTALL' (command '$CMD_TO_CHECK') is already installed."
else
    echo "Package '$PACKAGE_TO_INSTALL' (command '$CMD_TO_CHECK') not found."
    NEEDS_INSTALL=true
fi

if [ "$NEEDS_INSTALL" = true ]; then
    echo "Attempting to install '$PACKAGE_TO_INSTALL'..."

    echo "Running sudo apt-get update -qq (this may take a moment if needed)..."
    # Consider making 'apt-get update' conditional or less frequent if script is called many times.
    # For now, running it to ensure package lists are fresh before an install attempt.
    if ! sudo apt-get update -qq; then
        echo "[WARN] 'apt-get update' failed. Proceeding with install attempt for '$ACTUAL_PACKAGE_NAME', but it might fail if package lists are stale." >&2
    fi

    echo "Installing '$ACTUAL_PACKAGE_NAME' (provides command '$CMD_TO_CHECK') via apt-get..."
    if sudo apt-get install -y "$ACTUAL_PACKAGE_NAME"; then
        if is_installed "$CMD_TO_CHECK"; then
            echo "Package '$ACTUAL_PACKAGE_NAME' installed successfully (command '$CMD_TO_CHECK' is now available)."
        else
            echo "[ERROR] 'apt-get install' for '$ACTUAL_PACKAGE_NAME' reported success, but command '$CMD_TO_CHECK' is still not found." >&2
            exit 1
        fi
    else
        echo "[ERROR] Failed to install package '$ACTUAL_PACKAGE_NAME' using apt-get. Please check messages above." >&2
        exit 1
    fi
fi
echo ""
echo "Base utility check/installation for '$PACKAGE_TO_INSTALL' complete."
exit 0
