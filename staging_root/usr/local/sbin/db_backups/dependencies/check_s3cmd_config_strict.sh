#!/bin/bash
# =============================================================================
# Script: check_s3cmd_config_strict.sh
# Purpose: Checks if s3cmd is configured by looking for the ~/.s3cfg file and
#          attempting a basic 's3cmd ls' command. This is a strict check and
#          will exit with an error if the configuration is missing or invalid.
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
# - This script is used when a valid s3cmd configuration is mandatory for the
#   calling process to continue.
# - The HOME environment variable must be correctly set for the user running this script.
# =============================================================================
# Do not set -e here, as we want to capture the exit status of s3cmd

echo "Performing STRICT check of s3cmd configuration status..."
echo ""

S3CFG_FILE="$HOME/.s3cfg" # s3cmd typically uses this path

if [ ! -f "$S3CFG_FILE" ]; then
    echo ""
    echo " ------ S3CMD CONFIGURATION ERROR ------" >&2
    echo "[ERROR] s3cmd configuration file ('$S3CFG_FILE') not found." >&2
    echo "[ACTION REQUIRED] s3cmd may not be configured. Please run 's3cmd --configure'." >&2
    echo "[ACTION REQUIRED] Cloud backups cannot proceed without s3cmd configuration." >&2
    echo ""
    exit 1
fi

echo "s3cmd configuration file ('$S3CFG_FILE') found."
echo "Attempting a basic 's3cmd ls' to further check configuration..."

if s3cmd ls > /dev/null 2>&1; then
    echo "'s3cmd ls' command SUCCEEDED. s3cmd is configured and credentials appear valid."
    exit 0
else
    status_code=$?
    echo ""
    echo " ------ S3CMD CONFIGURATION ERROR ------" >&2
    echo "[ERROR] 's3cmd ls' command FAILED (exit code: $status_code)." >&2
    echo "[ERROR] This may indicate issues with the credentials or permissions in '$S3CFG_FILE'," >&2
    echo "[ERROR] or general S3 access problems." >&2
    echo "[ACTION REQUIRED] Please review your s3cmd configuration (run 's3cmd --configure') or check S3 permissions." >&2
    echo "[ACTION REQUIRED] Cloud backups cannot proceed without valid s3cmd configuration and S3 access." >&2
    echo ""
    exit 1
fi
