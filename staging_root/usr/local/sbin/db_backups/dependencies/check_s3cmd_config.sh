#!/bin/bash
# =============================================================================
# Script: check_s3cmd_config.sh
# Purpose: Checks if s3cmd appears to be configured by looking for the ~/.s3cfg
#          file and, if found, attempting a basic 's3cmd ls' command to
#          verify the configuration.
# Copyright: (c) 2025 Alejandro Capuro Meyer. All rights reserved.
# License: GPL v3 - see LICENSE file for details
# Development: This script was developed with AI assistance (including Gemini,
#              ChatGPT, Claude, Jules, Firebase, and others) under human
#              guidance for architecture, logic design, and project direction.
# File Version: 20250723.154400
# Project Repository: https://github.com/capuromeyer/db_backups
# Usage: This script is intended to be called by other scripts (e.g., preflight checks)
#        and is not meant for direct execution.
#
# Notes:
# - This is a non-strict check and will only print a warning if the s3cmd
#   configuration is missing or invalid; it will not cause the calling script to exit.
# - The HOME environment variable must be correctly set for the user running this script.
# =============================================================================
# Do not set -e here, as we want to capture the exit status of s3cmd

echo "Checking s3cmd configuration status (non-strict)..."
echo ""

S3CFG_FILE="$HOME/.s3cfg" # s3cmd typically uses this path

if [ ! -f "$S3CFG_FILE" ]; then
    echo "[WARNING] s3cmd configuration file ('$S3CFG_FILE') not found."
    echo "[WARNING] s3cmd may not be configured. Please run 's3cmd --configure'."
    echo "[WARNING] Preflight checks will continue, but S3 operations requiring s3cmd may fail." >&2
    exit 0
fi

echo "s3cmd configuration file ('$S3CFG_FILE') found."
echo "Attempting a basic 's3cmd ls' to further check configuration..."

if s3cmd ls > /dev/null 2>&1; then
    echo "'s3cmd ls' command succeeded. s3cmd appears configured and credentials likely valid."
else
    status_code=$?
    echo "[WARNING] 's3cmd ls' command failed (exit code: $status_code)."
    echo "[WARNING] This may indicate issues with the credentials or permissions in '$S3CFG_FILE',"
    echo "[WARNING] or general S3 access problems."
    echo "[WARNING] Please review your s3cmd configuration (run 's3cmd --configure') or check S3 permissions."
    echo "[WARNING] Preflight checks will continue, but S3 operations requiring s3cmd may fail." >&2
fi

exit 0
