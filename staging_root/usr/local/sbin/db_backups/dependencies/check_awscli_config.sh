#!/bin/bash
# -----------------------------------------------------------------------------
# Script: check_awscli_config.sh
# Purpose: Checks if AWS CLI appears to be configured by attempting a
#          read-only command (sts get-caller-identity).
# Author: Alejandro Capuro (Original tool concept) / Jules (Script generation)
# Copyright: (c) $(date +%Y) Alejandro Capuro. All rights reserved.
# Version: 0.1.0
#
# Notes:
#   - Called by preflight.sh.
#   - Does not exit fatally, only prints warnings.
# -----------------------------------------------------------------------------
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
