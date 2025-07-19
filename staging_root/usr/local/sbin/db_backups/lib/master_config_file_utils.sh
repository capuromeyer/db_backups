#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Script: master_config_file_utils.sh
# Purpose: Utility to process a manifest of project config files, validate them,
#          and report valid/invalid configs as well as duplicates.
# Developed by: Alejandro Capuro (Project Lead & Logic Design)
# Implemented by: AI Assistant, under guidance
# Copyright: (c) 2025 Alejandro Capuro. All rights reserved.
# File Version: 20250712.000000
# Project Version: 1.0.0
#
# Functions:
#   process_and_report_configs(manifest_file)
#   detect_and_report_duplicates(manifest_file)
# -----------------------------------------------------------------------------
# This script provides functions that:
#   1. Reads a manifest file listing project config paths (with optional "include" syntax).
#   2. Ignores comments (#) and blank lines.
#   3. Strips the "include" keyword and trailing semicolons.
#   4. Checks each file for existence and readability.
#   5. Prints a detailed summary (to stderr) marking each path Valid/Invalid.
#   6. Identifies duplicates by project name and reports Unique/Duplicate listings.
#   7. Provides totals for both validation and duplicate checks.
#   8. Creates a file with unique config paths and outputs its path as the first line.
#
# Usage:
#   source this script, then call:
#     process_and_report_configs /etc/db_backups/db_backups.conf
#     unique_file_path=$(detect_and_report_duplicates /etc/db_backups/db_backups.conf)

set -euo pipefail

# -----------------------------------------------------------------------------
# FUNCTION: process_and_report_configs
# Purpose : Parse manifest, report valid vs invalid entries
# Arguments:
#   $1: Path to manifest file
# Outputs : stderr: table of valid vs invalid files and totals
# Returns : 0 if at least one valid file; 1 otherwise
# -----------------------------------------------------------------------------
process_and_report_configs() {
    local manifest_file="$1"
    local -a valid_files=()
    local -a invalid_files=()
    local line trimmed

    # Validate manifest argument
    if [[ -z "$manifest_file" || ! -f "$manifest_file" ]]; then
        echo "[CONFIG ERROR] Missing or invalid manifest: $manifest_file" >&2
        return 1
    fi

    # Parse manifest: strip comments, trim, handle include/semicolons
    while IFS= read -r line || [[ -n "$line" ]]; do
        trimmed="${line%%#*}"
        trimmed="${trimmed#${trimmed%%[![:space:]]*}}"
        trimmed="${trimmed%${trimmed##*[![:space:]]}}"
        if [[ $trimmed =~ ^include[[:space:]]+(.+) ]]; then
            trimmed="${BASH_REMATCH[1]}"
        fi
        trimmed="${trimmed%;}"
        [[ -z "$trimmed" ]] && continue

        # Classify existence
        if [[ -f "$trimmed" && -r "$trimmed" ]]; then
            valid_files+=("$trimmed")
        else
            invalid_files+=("$trimmed")
        fi
    done < "$manifest_file"

    # Report summary to stderr
    echo '----------------------------------------' >&2
    echo 'Master Config File List:' >&2
    echo '----------------------------------------' >&2
    printf '%-50s | %s\n' 'File' 'Status' >&2
    echo '----------------------------------------' >&2
    for f in "${valid_files[@]}"; do
        printf '%-50s | %s\n' "$f" 'Valid' >&2
    done
    for f in "${invalid_files[@]}"; do
        printf '%-50s | %s\n' "$f" 'Invalid' >&2
    done
    echo '----------------------------------------' >&2
    echo "Total: $(( ${#valid_files[@]} + ${#invalid_files[@]} )), Valid: ${#valid_files[@]}, Invalid: ${#invalid_files[@]}" >&2
    echo '----------------------------------------' >&2
    echo "" >&2

    # Return status based on valid files
    if (( ${#valid_files[@]} > 0 )); then
        return 0
    else
        return 1
    fi
}

# -----------------------------------------------------------------------------
# FUNCTION: detect_and_report_duplicates
# Purpose : Builds list of valid config files from manifest, then identifies
#           and reports duplicates by project name using "Unique"/"Duplicate".
#           Outputs unique file path as the very first line to stdout,
#           followed by the full duplicate/unique report and all
#           informational/error messages to stdout.
# Arguments:
#   $1: Path to manifest file
# Outputs : stdout: The path to the generated unique config file (first line),
#                   followed by the full duplicate/unique report and all
#                   informational/error messages.
# Returns : 0 on success, 1 on error.
# -----------------------------------------------------------------------------
detect_and_report_duplicates() {
    local manifest_file="$1"
    local -a valid_files=()         # Stores only valid and readable files
    local -a unique_files_for_file_creation=() # Stores unique valid files for the output file
    local -A name_counts=() # To count occurrences for duplicate detection
    local line trimmed file pname status
    local current_unique_count=0
    local current_duplicate_count=0
    local output_file # Declare early for the first echo

    # Generate timestamp and output_file path *first*
    local timestamp=$(date +%Y-%m-%d-%H%M%S)
    local output_dir="/etc/db_backups/autogen_conf.d"
    output_file="${output_dir}/db_uniques_autogen_${timestamp}.conf"

    # ECHO THE FILENAME AS THE VERY FIRST OUTPUT TO STDOUT
    echo "$output_file"

    # Validate manifest argument
    if [[ -z "$manifest_file" || ! -f "$manifest_file" ]]; then
        echo "[ERROR] Missing or invalid manifest: $manifest_file"
        return 1
    fi

    # --- Initial Parsing and Classification (Valid/Invalid files for duplicate check) ---
    # This logic is specifically for populating valid_files for duplicate checking.
    while IFS= read -r line || [[ -n "$line" ]]; do
        trimmed="${line%%#*}"
        trimmed="${trimmed#${trimmed%%[![:space:]]*}}"
        trimmed="${trimmed%${trimmed##*[![:space:]]}}"
        if [[ $trimmed =~ ^include[[:space:]]+(.+) ]]; then
            trimmed="${BASH_REMATCH[1]}"
        fi
        trimmed="${trimmed%;}"
        [[ -z "$trimmed" ]] && continue

        # Only add to valid_files if it exists and is readable for duplicate detection
        if [[ -f "$trimmed" && -r "$trimmed" ]]; then
            valid_files+=("$trimmed")
        fi
    done < "$manifest_file"

    # --- Duplicate Detection and Reporting (ONLY on Valid Files) ---

    # Count project-name occurrences from valid_files
    for file in "${valid_files[@]}"; do
        pname="${file##*/}"
        pname="${pname%.conf}"
        (( name_counts["$pname"]++ ))
    done

    # Report header for duplicates
    echo ''
    echo '----------------------------------------'
    echo 'Project Duplicate/Unique Report:'
    echo '----------------------------------------'
    printf '%-50s | %s\n' 'File' 'Status'
    echo '----------------------------------------'

    # Print status for each valid file (to stdout) and update report counts
    for file in "${valid_files[@]}"; do
        pname="${file##*/}"; pname="${pname%.conf}"
        if (( name_counts["$pname"] > 1 )); then
            status='Duplicate'
            (( current_duplicate_count++ ))
        else
            status='Unique'
            (( current_unique_count++ ))
            unique_files_for_file_creation+=("$file") # Add to unique files list for file creation
        fi
        printf '%-50s | %s\n' "$file" "$status"
    done

    # Summary for duplicates
    echo '----------------------------------------'
    echo "Total: $(( current_unique_count + current_duplicate_count )), Unique: ${current_unique_count}, Duplicate: ${current_duplicate_count}"
    echo "----------------------------------------"
    echo ""

    # --- Create Unique Config File ---

    # Define the header content for the auto-generated file
    local header_content="# This file is auto-generated by db_backup system scripts.\n"
    header_content+="# DO NOT MODIFY THIS FILE MANUALLY.\n"
    header_content+="# This file will be automatically deleted after use.\n"
    header_content+="# Access restricted to root only.\n\n"
    header_content+="# List of unique valid files to load for backup\n"
    header_content+="# Run at: $timestamp\n\n" # Added timestamp to header

    # Create the output directory if it doesn't exist
    mkdir -p "$output_dir" || {
        echo "[ERROR] Could not create directory: $output_dir"
        return 1
    }

    # Write the header and unique files to the new file
    printf "%b" "$header_content" > "$output_file" || {
        echo "[ERROR] Could not write header to: $output_file"
        return 1
    }
    printf "%s\n" "${unique_files_for_file_creation[@]}" >> "$output_file" || {
        echo "[ERROR] Could not write unique files to: $output_file"
        return 1
    }

    # Set file permissions to root-only (read/write for owner, no access for others)
    chmod 600 "$output_file" || {
        echo "[ERROR] Could not set permissions for: $output_file"
        return 1
    }

    # This informational message goes to stdout as requested
    echo "[MANIFEST] INFO Unique files saved to:"
    echo "$output_file"

    return 0
}
