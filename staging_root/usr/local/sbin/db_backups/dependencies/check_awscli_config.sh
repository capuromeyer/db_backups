#!/bin/bash
# =============================================================================
# Script: check_awscli_config.sh
# Purpose: Checks if the AWS CLI appears to be configured by attempting a
#          read-only command (sts get-caller-identity).
# Copyright: (c) 2025 Alejandro Capuro Meyer. All rights reserved.
# License: GPL v3 - see LICENSE file for details
# Development: This script was developed with AI assistance (including Gemini,
#              ChatGPT, Claude, Jules, Firebase, and others) under human
#              guidance for architecture, logic design, and project direction.
# File Version: 20250723.153800
# Project Version: 1.0.0
# Project Repository: https://github.com/capuromeyer/db_backups
# Usage: This script is intended to be called by other scripts (e.g., preflight checks)
#        and is not meant for direct execution.
#
# Notes:
# - This is a non-strict check and will only print a warning if the AWS CLI
#   command fails; it will not cause the calling script to exit.
# =============================================================================
# set -e # Do not set -e here, as we want to capture the exit code of aws command

echo "Checking AWS CLI configuration status (non-strict)..."
echo ""

# Attempt to get caller identity.
if aws sts get-caller-identity --output text > /dev/null 2>&1; then
    echo "AWS CLI 'sts get-caller-identity' command succeeded."
    echo "AWS CLI appears configured and credentials likely valid."
    exit 0
else
    status_code=$?
    echo "[WARNING] AWS CLI 'sts get-caller-identity' command failed (exit code: $status_code)."
    echo "[WARNING] This may indicate that AWS CLI is not configured correctly, credentials are missing/invalid," >&2
    echo "[WARNING] or there are network/permission issues preventing communication with AWS STS." >&2
    echo "[WARNING] Please run 'aws configure' to set up your credentials and default region." >&2
    echo "[WARNING] Preflight checks will continue, but S3 operations requiring AWS CLI may fail." >&2
    exit 0 # Exiting 0 as this is a non-strict check.
fi
