#!/bin/bash
# -----------------------------------------------------------------------------
# Script: check_s3cmd_config.sh
# Purpose: Checks if s3cmd appears to be configured by looking for ~/.s3cfg
#          and attempting a basic 's3cmd ls' command.
# Author: Alejandro Capuro (Original tool concept) / Jules (Script generation)
# Copyright: (c) $(date +%Y) Alejandro Capuro. All rights reserved.
# Version: 0.1.0
#
# Notes:
#   - Called by preflight.sh.
#   - Does not exit fatally, only prints warnings.
#   - HOME environment variable must be correctly set for the user running this.
# -----------------------------------------------------------------------------
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
