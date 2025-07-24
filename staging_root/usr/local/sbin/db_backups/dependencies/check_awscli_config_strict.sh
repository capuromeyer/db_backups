#!/bin/bash
# =============================================================================
# Script: check_awscli_config_strict.sh
# Purpose: Checks if the AWS CLI is configured by attempting 'sts get-caller-identity'.
#          This is a strict check, and the script will exit with an error if the
#          command fails.
# Copyright: (c) 2025 Alejandro Capuro Meyer. All rights reserved.
# License: GPL v3 - see LICENSE file for details
# Development: This script was developed with AI assistance (including Gemini,
#              ChatGPT, Claude, Jules, Firebase, and others) under human
#              guidance for architecture, logic design, and project direction.
# File Version: 20250723.153900
# Project Version: 1.0.0
# Project Repository: https://github.com/capuromeyer/db_backups
# Usage: This script is intended to be called by other scripts (e.g., preflight checks)
#        and is not meant for direct execution.
#
# Notes:
# - This script is used when a valid AWS CLI configuration is mandatory for the
#   calling process to continue.
# =============================================================================
# set -e # Do not set -e here, as we want to capture the exit code of aws command

echo "Performing STRICT check of AWS CLI configuration status..."
echo ""

# Attempt to get caller identity.
if aws sts get-caller-identity --output text > /dev/null 2>&1; then
    echo "AWS CLI 'sts get-caller-identity' command SUCCEEDED."
    echo "AWS CLI is configured and credentials appear valid."
    exit 0
else
    status_code=$?
    echo ""
    echo " ------ AWS CLI CONFIGURATION ERROR ------" >&2
    echo "[ERROR] AWS CLI 'sts get-caller-identity' command FAILED (exit code: $status_code)." >&2
    echo "[ERROR] This indicates that AWS CLI is not configured correctly, credentials are missing/invalid," >&2
    echo "[ERROR] or there are network/permission issues preventing communication with AWS STS." >&2
    echo "[ACTION REQUIRED] Please run 'aws configure' to set up your credentials and default region." >&2
    echo "[ACTION REQUIRED] Cloud backups cannot proceed without valid AWS CLI configuration." >&2
    echo ""
    exit 1
fi
