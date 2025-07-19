#!/bin/bash
# -----------------------------------------------------------------------------
# Script: check_awscli_config_strict.sh
# Purpose: Checks if AWS CLI is configured by attempting 'sts get-caller-identity'.
#          Exits with error if the check fails.
# Author: Alejandro Capuro (Original tool concept) / Jules (Script generation)
# Copyright: (c) $(date +%Y) Alejandro Capuro. All rights reserved.
# Version: 0.1.0
#
# Notes:
#   - Called by preflight.sh when cloud backups are mandatory.
#   - Exits with status 1 if configuration check fails.
# -----------------------------------------------------------------------------
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
