#!/bin/bash
# -----------------------------------------------------------------------------
# Script: install_dependencies.sh
# Purpose: Orchestrates the installation of all required dependencies for the
#          db_backups tool by calling individual installer scripts.
#          Dependencies include: zip, bc, s3cmd, aws-cli (via Snap).
# Author: Alejandro Capuro (Original tool concept) / Jules (Script generation)
# Copyright: (c) $(date +%Y) Alejandro Capuro. All rights reserved.
# Version: 0.1.0
#
# Usage:
#   sudo ./install_dependencies.sh
#   (Typically called by online_install.sh or preflight.sh individual calls)
#
# Notes:
#   - Must be run with sudo or as root due to package installations.
#   - Calls sub-scripts located in ./dependencies/
# -----------------------------------------------------------------------------

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
