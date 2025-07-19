#!/bin/bash
# -----------------------------------------------------------------------------
# Script: install_awscli_snap.sh
# Purpose: Installs AWS CLI (aws-cli) using Snap.
#          Also installs snapd if it's not already present.
# Author: Alejandro Capuro (Original tool concept) / Jules (Script generation)
# Copyright: (c) 2025 Alejandro Capuro. All rights reserved.
# File Version: 20250702.203000 # Updated timestamp
# Project Version: 1.0.0
#
# Notes:
#   - Requires sudo for apt and snap install commands.
#   - Idempotent: checks if AWS CLI is already installed.
# -----------------------------------------------------------------------------

set -e

echo "--- AWS CLI Installer (via Snap) ---"
echo "Checking AWS CLI status..."
if command -v aws &> /dev/null; then
    echo "AWS CLI is already installed."
    aws --version
    echo "--- AWS CLI check complete ---"
    exit 0
fi

echo "AWS CLI not found."
echo ""

# Check for Snapd
echo "Checking for snapd..."
if ! command -v snap &> /dev/null; then
    echo "Snapd not found. Attempting to install snapd..."
    # These sudo commands will prompt for password if not run as root already
    sudo apt update
    sudo apt install -y snapd
    if ! command -v snap &> /dev/null; then
        echo "[ERROR] Failed to install snapd. Please install snapd manually and try again." >&2
        exit 1
    fi
    echo "Snapd installed successfully."
else
    echo "Snapd is already installed."
fi
echo ""

# Install AWS CLI via Snap
echo "Attempting to install AWS CLI via Snap (this may take a few moments)..."
if sudo snap install aws-cli --classic; then
    echo "AWS CLI 'snap install' command completed."
else
    echo "[ERROR] 'sudo snap install aws-cli --classic' command failed. AWS CLI may not be installed." >&2
    # Even if snap install fails, we'll try to see if aws command became available,
    # though it's unlikely. The error from snap should be the primary indicator.
fi
echo ""

# Verify installation and PATH
echo "Verifying AWS CLI installation and PATH..."
if ! command -v aws &> /dev/null; then
    echo "AWS CLI command still not found in PATH after installation attempt."
    echo "Attempting to source common profile files to update PATH for current session (this may not always work)..."
    [ -f "$HOME/.profile" ] && source "$HOME/.profile" >/dev/null 2>&1
    [ -f "$HOME/.bash_profile" ] && source "$HOME/.bash_profile" >/dev/null 2>&1
    [ -f "$HOME/.bashrc" ] && source "$HOME/.bashrc" >/dev/null 2>&1

    if ! command -v aws &> /dev/null; then
        echo "[ERROR] Failed to find AWS CLI in PATH even after attempting to source profiles." >&2
        echo "If 'snap install' reported success, AWS CLI might be installed but '/snap/bin' may not be in your PATH for this session or for the current user." >&2
        echo "Please try opening a new terminal session, or manually add '/snap/bin' to your PATH (e.g., in .bashrc or .profile)." >&2
        echo "Common AWS CLI location via snap: /snap/bin/aws" >&2
        exit 1
    fi
fi

echo "AWS CLI installed and found in PATH."
aws --version
echo ""
echo "--- AWS CLI Installer finished ---"
exit 0
