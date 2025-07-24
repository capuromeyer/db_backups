#!/bin/bash
# =============================================================================
# Script: install_dependencies.sh
# Purpose: Orchestrates the installation of all required dependencies for the
#          db_backups tool by calling individual installer scripts for zip, bc,
#          s3cmd, and the AWS CLI.
# Copyright: (c) 2025 Alejandro Capuro Meyer. All rights reserved.
# License: GPL v3 - see LICENSE file for details
# Development: This script was developed with AI assistance (including Gemini,
#              ChatGPT, Claude, Jules, Firebase, and others) under human
#              guidance for architecture, logic design, and project direction.
# File Version: 20250723.154900
# Project Repository: https://github.com/capuromeyer/db_backups
# Usage: sudo ./install_dependencies.sh
#   (This script is typically called by other scripts like online_install.sh)
#
# Notes:
# - Must be run with sudo or as root due to package installations.
# - This script calls sub-scripts located in the ./dependencies/ directory.
# =============================================================================

set -e

# Get the directory of the script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

echo "Starting dependency installation process..."
echo "----------------------------------------"

echo "Running base utility installer for 'zip'..."
if "$SCRIPT_DIR/dependencies/install_base_utils.sh" zip; then
    echo "'zip' installation check completed."
else
    echo "Failed during 'zip' installation check."
    exit 1
fi
echo "----------------------------------------"

echo "Running base utility installer for 'bc'..."
if "$SCRIPT_DIR/dependencies/install_base_utils.sh" bc; then
    echo "'bc' installation check completed."
else
    echo "Failed during 'bc' installation check."
    exit 1
fi
echo "----------------------------------------"

echo "Running s3cmd installer..."
if "$SCRIPT_DIR/dependencies/install_s3cmd.sh"; then
    echo "s3cmd installation script completed."
else
    echo "s3cmd installation script failed."
    exit 1
fi
echo "----------------------------------------"

echo "Running AWS CLI (Snap) installer..."
if "$SCRIPT_DIR/dependencies/install_awscli_snap.sh"; then
    echo "AWS CLI (Snap) installation script completed."
else
    echo "AWS CLI (Snap) installation script failed."
    exit 1
fi
echo "----------------------------------------"

echo "All dependency checks/installations complete."
exit 0
