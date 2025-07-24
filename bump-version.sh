#!/bin/bash
# =============================================================================
# Script: bump-version.sh
# Purpose: Manages the project version by updating the content of a dedicated
#          'VERSION' file. This script expects a 'VERSION' file to exist
#          in the project's root directory and will overwrite its content
#          with the new version string provided as an argument.
# Copyright: (c) 2025 Alejandro Capuro Meyer. All rights reserved.
# License: GPL v3 - see LICENSE file for details
# Development: This script was developed with AI assistance (including Gemini,
#              ChatGPT, Claude, Jules, Firebase, and others) under human
#              guidance for architecture, logic design, and project direction.
# File Version: 20250724.155000
# Project Version: 1.0.0
# Project Repository: Not applicable (local utility script)
# Usage: Execute from the project's root directory: ./bump-version.sh <new_version>
#        Example: ./bump-version.sh 1.0.1
#
# Notes:
# - This script directly overwrites the content of the 'VERSION' file.
#   Ensure the 'VERSION' file exists and contains only the version string.
# - It's recommended to commit your changes or back up your project before running.
# =============================================================================

VERSION_FILE="VERSION"

# Check if a new version argument is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <new_version>"
  echo "Example: $0 1.0.1"
  exit 1
fi

NEW_VERSION="$1"

# Check if the VERSION file exists
if [ ! -f "$VERSION_FILE" ]; then
  echo "Error: The '$VERSION_FILE' file does not exist in the current directory."
  echo "Please create a '$VERSION_FILE' file with the current version (e.g., '1.0.0') before running this script."
  exit 1
fi

echo "Updating project version in '$VERSION_FILE' to: $NEW_VERSION"

# Overwrite the content of the VERSION_FILE with the new version
# Using 'echo' to directly write the new version to the file.
echo "$NEW_VERSION" > "$VERSION_FILE"

# Verify the update
if [ "$(cat "$VERSION_FILE")" = "$NEW_VERSION" ]; then
  echo "Successfully updated '$VERSION_FILE' to $NEW_VERSION."
else
  echo "Error: Failed to update '$VERSION_FILE'."
  exit 1
fi

echo "Version bump complete."
