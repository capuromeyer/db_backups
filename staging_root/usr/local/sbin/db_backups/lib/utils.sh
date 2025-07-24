#!/bin/bash
# =============================================================================
# Script: utils.sh
# Purpose: Provides general utility functions for the db_backups project.
# Copyright: (c) 2025 Alejandro Capuro Meyer. All rights reserved.
# License: GPL v3 - see LICENSE file for details
# Development: This script was developed with AI assistance (including Gemini,
#              ChatGPT, Claude, Jules, Firebase, and others) under human
#              guidance for architecture, logic design, and project direction.
# File Version: 20250723.160700
# Project Repository: https://github.com/capuromeyer/db_backups
# Usage: This script is intended to be sourced by other scripts.
#
# Notes:
# - This script is not meant for direct execution.
# =============================================================================

# Function to check if the script is running as root.
# Outputs an error message and exits if not run as root.
check_root() {
    # Check if the effective user ID is 0 (root)
    if [ "$(id -u)" -ne 0 ]; then
        # Display a user-friendly error message with a specific prefix
        echo "[ERROR_PERMISSION] This operation requires root privileges." >&2
        echo "Please run this script using sudo: sudo $0" >&2
        # Exit with a status code indicating a permission error
        exit 1
    fi
    # Inform the user that the check passed
    echo "[INFO] Root privileges check passed."
    echo ""
}