#!/bin/bash
# =============================================================================
# Script: config_loader.sh
# Purpose: Parses a main manifest configuration file, processes 'include'
#          directives within it (including globs), and outputs a list of
#          resolved, unique, and actual configuration file paths to be
#          processed individually.
# Copyright: (c) 2025 Alejandro Capuro Meyer. All rights reserved.
# License: GPL v3 - see LICENSE file for details
# Development: This script was developed with AI assistance (including Gemini,
#              ChatGPT, Claude, Jules, Firebase, and others) under human
#              guidance for architecture, logic design, and project direction.
# File Version: 20250723.155300
# Project Version: 1.0.0
# Project Repository: https://github.com/capuromeyer/db_backups
# Usage: This script is intended to be sourced by other scripts. The main
#        function to be called is `get_active_config_paths_from_manifest`.
#
# Notes:
# - Handles 'include /path/to/file.conf' and 'include /path/to/*.conf'.
# - Requires absolute paths for includes.
# - Protects against recursive includes of manifest files.
# - The output is one fully qualified file path per line for each active project config.
# =============================================================================

# Array to keep track of already processed manifest files to prevent recursion
_PROCESSED_MANIFEST_FILES=()
# Array to store the paths of collected project config files
_COLLECTED_PROJECT_CONFIG_FILES=()

# Array to store the original paths from include directives before processing
_ORIGINAL_INCLUDE_PATHS=()
# Global counter for the total number of include directives processed
_TOTAL_INCLUDE_DIRECTIVES_COUNT=0
# Function to check if a manifest file has already been processed
# Usage: _has_been_processed_manifest "/path/to/file"
_has_been_processed_manifest() {
    local file_to_check="$1"
    local processed_file
    for processed_file in "${_PROCESSED_MANIFEST_FILES[@]}"; do
        if [[ "$processed_file" == "$file_to_check" ]]; then
            return 0 # True, has been processed
        fi
    done
    return 1 # False, not processed
}

# Internal recursive function to process a manifest file and its includes.
# It populates _COLLECTED_PROJECT_CONFIG_FILES.
# Usage: _process_manifest_recursively "/path/to/manifest.conf"
_process_manifest_recursively() {
    local manifest_file_path="$1"
 # Initialize include counter for this manifest file processing call
 local include_counter_this_call=0
    local real_manifest_path

    # Resolve to real path to handle symlinks and normalize for tracking
    if ! real_manifest_path=$(realpath -e "$manifest_file_path" 2>/dev/null); then
 echo "[CONFIG ERROR_FILE_ACCESS] Failed to access included manifest file '$manifest_file_path'. Please check if the file exists and has correct read permissions. Skipping this include." >&2
        return
    fi

    if _has_been_processed_manifest "$real_manifest_path"; then
 echo "[CONFIG WARN_RECURSIVE_INCLUDE] Recursive manifest include detected for '$real_manifest_path'. This file has already been processed in this manifest parsing run and will be skipped to prevent an infinite loop. Please review your manifest include directives." >&2
        return
    fi
    _PROCESSED_MANIFEST_FILES+=("$real_manifest_path")

    # echo "[DEBUG] Processing manifest file: $real_manifest_path" >&2 # For debugging

    # Read the manifest file and process 'include' directives
    # Process only non-commented include lines
    local line
    while IFS= read -r line || [[ -n "$line" ]]; do # Process last line even if no newline
        local original_line="$line"
        # Remove leading/trailing whitespace from the line
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"

        # Skip empty lines or lines not starting with "include"
        if [ -z "$line" ] || [[ "$line" != include* ]]; then
            continue
        fi

 # Increment the include counter for valid include lines
 include_counter_this_call=$((include_counter_this_call + 1))

        # Valid include line, extract the path or glob
 # Store the original include path before processing
 _ORIGINAL_INCLUDE_PATHS+=("$original_line")

        local include_path_or_glob
        include_path_or_glob="${line#include}"
        include_path_or_glob="${include_path_or_glob#"${include_path_or_glob%%[![:space:]]*}"}" # Trim leading space
        include_path_or_glob="${include_path_or_glob%"${include_path_or_glob##*[![:space:]]}"}"   # Trim trailing space
        include_path_or_glob="${include_path_or_glob%;}" # Remove trailing semicolon if present
        include_path_or_glob="${include_path_or_glob%\"}" # Remove trailing quote
        include_path_or_glob="${include_path_or_glob#\"}" # Remove leading quote
        include_path_or_glob="${include_path_or_glob%\'}" # Remove trailing single quote
        include_path_or_glob="${include_path_or_glob#\'}" # Remove leading single quote


        if [ -z "$include_path_or_glob" ]; then
            echo "[CONFIG WARN] Found 'include' directive with empty path in '$real_manifest_path' (original: '$original_line'). Skipping." >&2
 continue
        fi

        if [[ "$include_path_or_glob" != /* ]]; then
 echo "[CONFIG WARN_RELATIVE_PATH] The include path '$include_path_or_glob' in manifest file '$real_manifest_path' is not an absolute path. Relative paths are not supported for include directives. Please update the path to be absolute. Skipping this include." >&2
 continue
        fi

        local discovered_files_for_this_include=()
        local old_ifs="$IFS"
        IFS=$'\n' # Handle spaces in filenames from glob output (less likely for .conf)

        shopt -s nullglob # If glob matches nothing, it expands to empty, not the pattern itself
        local file_match # Ensure file_match is local to the loop
        for file_match in $include_path_or_glob; do # Relies on word splitting for glob
             if [ -f "$file_match" ]; then
                 # Resolve to real path before adding
                 local real_file_match_path # Ensure real_file_match_path is local
                 if real_file_match_path=$(realpath -e "$file_match" 2>/dev/null); then
                    discovered_files_for_this_include+=("$real_file_match_path")
                 else
 echo "[CONFIG WARN_INACCESSIBLE_GLOB] The included file '$file_match' matched by a glob in '$real_manifest_path' was not found or became inaccessible after processing the include directive. Please verify the file exists and is readable. Skipping this file." >&2
                 fi
             elif [ -d "$file_match" ]; then
 echo "[CONFIG WARN_IS_DIRECTORY] The path '$file_match' specified in an include directive in '$real_manifest_path' points to a directory. Only individual project configuration files are supported. Skipping this entry." >&2
 # else: glob matched nothing or matched something not a file or dir, nullglob handles it.
             fi
        done
        shopt -u nullglob # Reset nullglob
        IFS="$old_ifs"

        if [ ${#discovered_files_for_this_include[@]} -eq 0 ] && [[ "$include_path_or_glob" != *"*"* ]] && [[ "$include_path_or_glob" != *"?"* ]] && [[ "$include_path_or_glob" != *"["* ]]; then
             # Specific file was included but not found (and it wasn't a glob that might find nothing)
 echo "[CONFIG WARN_FILE_NOT_FOUND] The specific file '$include_path_or_glob' referenced in an include directive in '$real_manifest_path' was not found or is not a regular file. Please ensure the file exists and the path is correct. Skipping this include." >&2
        fi

        local resolved_project_file_path # Ensure resolved_project_file_path is local
        for resolved_project_file_path in "${discovered_files_for_this_include[@]}"; do
            # Here, we assume that included files are project config files,
            # not other manifest files to be recursively processed for more includes.
            _COLLECTED_PROJECT_CONFIG_FILES+=("$resolved_project_file_path")
        done
    done < <(grep --color=never -E '^\s*include\s+' "$real_manifest_path" || true)
 # Add the count from this manifest file to the global total
 _TOTAL_INCLUDE_DIRECTIVES_COUNT=$((_TOTAL_INCLUDE_DIRECTIVES_COUNT + include_counter_this_call))

}

# Main function to be called by frequency scripts.
# Usage: get_active_config_paths_from_manifest "/path/to/main_manifest.conf"
# Output: Prints one fully qualified project config file path per line, unique.
get_active_config_paths_from_manifest() {
    local main_manifest_file="$1"

    if [ -z "$main_manifest_file" ]; then
 echo "[CONFIG ERROR_MISSING_MANIFEST_PATH] The main manifest file path was not provided to the configuration loading function. This is a required argument. Please ensure the main manifest file path is passed correctly." >&2
        return 1 # Error
    fi

    if [ ! -f "$main_manifest_file" ]; then
 echo "[CONFIG ERROR_MANIFEST_NOT_FOUND] The main manifest file '$main_manifest_file' was not found or is not a regular file. This file is required to load the project configurations. Please verify the file path and ensure it exists and is accessible." >&2
        return 1
    fi

    # Reset global arrays for this call
    _PROCESSED_MANIFEST_FILES=()
    _COLLECTED_PROJECT_CONFIG_FILES=()
 _ORIGINAL_INCLUDE_PATHS=() # Reset global array for original include paths
 _TOTAL_INCLUDE_DIRECTIVES_COUNT=0 # Reset global include counter

    _process_manifest_recursively "$main_manifest_file"

    # Output the total count of include directives as the first line to standard output
 echo "TOTAL_INCLUDES:$_TOTAL_INCLUDE_DIRECTIVES_COUNT"

 # Output the original include paths, one per line
    local original_include_path
    for original_include_path in "${_ORIGINAL_INCLUDE_PATHS[@]}"; do
 echo "$original_include_path"
    done



 # Output the total count of include directives as the first line to standard output
 echo "TOTAL_INCLUDES:$_TOTAL_INCLUDE_DIRECTIVES_COUNT"
    return 0
}

# Filters a list of configuration file paths to include only those that exist and are readable.
# It also populates the global arrays for reporting missing/unreadable files.
# Arguments:
#   $1: The name of the bash array containing the list of potential configuration file paths.
# Sets global variables:
#   TOTAL_CONFIGS_FROM_MANIFEST: Total number of paths in the input array.
#   MISSING_OR_UNREADABLE_FILES_REPORT_LINES: Array of formatted strings for reporting missing/unreadable files.
# Outputs:
#   Prints the paths of existing and readable configuration files to standard output,
#   one path per line.
# Returns:
#   0 on success.
# Developed by: Alejandro Capuro (Project Lead & Logic Design)
# Implemented by: Jules (AI Assistant, under guidance)
filter_existing_readable_configs() {
    local -n config_paths_array_ref="$1" # Use nameref to access the input array by name

    TOTAL_CONFIGS_FROM_MANIFEST=${#config_paths_array_ref[@]}
    MISSING_OR_UNREADABLE_FILES_REPORT_LINES=() # Reset the global reporting array

    local existing_and_readable_config_paths=()
    local invalid_configs_due_to_missing_files=0

    # Iterate through the provided paths and filter for existing and readable files
    for config_path in "${config_paths_array_ref[@]}"; do
        if [ -f "$config_path" ] && [ -r "$config_path" ]; then
            existing_and_readable_config_paths+=("$config_path")
        else
            printf "%-45s | %-20s | %-10s | %-25s | %s\n" "$config_path" "invalid" "N/A" "N/A" "Reason: File not found or not readable." >&2
            ((invalid_configs_due_to_missing_files++))
        fi
    done

    # Print the existing and readable paths to standard output
    printf "%s\n" "${existing_and_readable_config_paths[@]}"
}

# =============================================================================
# FUNCTION: validate_and_filter_configs
# Purpose: Reads potential configuration file paths from standard input,
# validates if each file exists and is readable, prints invalid file paths
# with reasons to standard error, and prints valid file paths to standard output.
# This function is intended to be used in a pipeline.
#
# Input:
#   Reads potential configuration file paths from standard input, one path per line.
#
# Output:
#   Prints valid configuration file paths to standard output, one path per line.
#   Prints information about invalid configuration files to standard error.
#
# Returns:
#   0 always. The success or failure of finding valid configs is determined
#   by the caller checking the standard output.
# Developed by: Alejandro Capuro (Project Lead & Logic Design)
# Implemented by: Jules (AI Assistant, under guidance)
# This function is being refactored to be the primary handler for loading,
# validating, and reporting on all configurations from the manifest based on resolved paths.
# =============================================================================

process_and_report_configs() {
    local main_manifest_file="$1"

    if [ -z "$main_manifest_file" ]; then
 echo "[CONFIG ERROR_MISSING_MANIFEST_PATH] The main manifest file path was not provided to the configuration processing function. This is a required argument. Please ensure the main manifest file path is passed correctly." >&2
        return 1 # Error
    fi

    if [ ! -f "$main_manifest_file" ]; then
 echo "[CONFIG ERROR_MANIFEST_NOT_FOUND] The main manifest file '$main_manifest_file' was not found or is not a regular file. This file is required to load the project configurations. Please verify the file path and ensure it exists and is accessible." >&2
        return 1
    fi

    # Reset global arrays for this call
    _PROCESSED_MANIFEST_FILES=()
    _COLLECTED_PROJECT_CONFIG_FILES=()
    _ORIGINAL_INCLUDE_PATHS=() # Reset global array for original include paths
    _TOTAL_INCLUDE_DIRECTIVES_COUNT=0 # Reset global include counter

    # Process the manifest and its includes. This populates _ORIGINAL_INCLUDE_PATHS
    # with all include directives found and sets _TOTAL_INCLUDE_DIRECTIVES_COUNT.
    # It also populates _COLLECTED_PROJECT_CONFIG_FILES with resolved paths that exist or could be globbed.
    _process_manifest_recursively "$main_manifest_file"

    local report_lines=()
    local valid_count=0
    local invalid_count=0 # Initialize invalid count based on original includes
    local valid_config_paths=() # To store paths that exist and are readable (resolved paths)

    # Create an associative array for quick lookup of collected/resolved paths
    local -A collected_paths_map=()
    local collected_path
    for collected_path in "${_COLLECTED_PROJECT_CONFIG_FILES[@]}"; do
        collected_paths_map["$collected_path"]=1
    done

    # Iterate through the original include paths and determine status for reporting
    local original_include_line
    for original_include_line in "${_ORIGINAL_INCLUDE_PATHS[@]}"; do
        local status="Invalid"
        local status_reason=""
        local original_path_or_glob

        # Extract the path or glob from the original include line (basic parsing)
        original_path_or_glob="${original_include_line#*include}"
        original_path_or_glob="${original_path_or_glob#"${original_path_or_glob%%[![:space:]]*}"}" # Trim leading space
        original_path_or_glob="${original_path_or_glob%"${original_path_or_glob##*[![:space:]]}"}"   # Trim trailing space
        original_path_or_glob="${original_path_or_glob%;}" # Remove trailing semicolon if present
        original_path_or_glob="${original_path_or_glob%\"}" # Remove trailing quote
        original_path_or_glob="${original_path_or_glob#\"}" # Remove leading quote
        original_path_or_glob="${original_path_or_glob%\'}" # Remove trailing single quote
        original_path_or_glob="${original_path_or_glob#\'}" # Remove leading single quote

        # Determine status based on whether the original path/glob resulted in collected files
        local matched_resolved_path=""

        # Simple check: if the original path (non-glob) is in our collected map and is readable
        if [[ "$original_path_or_glob" != *[?*[]* ]]; then # Not a glob pattern
             if real_resolved_path=$(realpath -e "$original_path_or_glob" 2>/dev/null); then
                 if [[ -n "${collected_paths_map[$real_resolved_path]}" ]]; then
                     # Double check existence and readability of the resolved path
                     if [ -f "$real_resolved_path" ] && [ -r "$real_resolved_path" ]; then
                         status="Valid"
                         matched_resolved_path="$real_resolved_path"
                         valid_config_paths+=("$matched_resolved_path") # Collect only truly valid resolved paths
                     else
                         status="Invalid"
                         status_reason="Resolved file not found or not readable."
                     fi
                 else
                     status="Invalid"
                     status_reason="Path did not resolve to a collected file."
                 fi
             else
                 status="Invalid"
                 status_reason="Original path not found or accessible."
             fi
        else # It's a glob pattern
            # For globs, we'll report them as 'Processed' if ANY files were collected
            # A more granular status for globs would require significant changes to _process_manifest_recursively
            if [ ${#_COLLECTED_PROJECT_CONFIG_FILES[@]} -gt 0 ]; then
                 status="Processed (check listed valid files)" # Indicates glob was processed
            fi
        fi

        report_lines+=("$(printf "%-45s | %s" "$original_include_line" "$status")")
    done

    echo "------------------------------------------------------------------------------" >&2
    # Using echo with padding for the summary line
    # Adjust spacing as needed for desired alignment
    echo "Total Projects on file =${#_COLLECTED_PROJECT_CONFIG_FILES[@]}  |  Total Valid =$valid_count   |  Total Invalid =$invalid_count" >&2
    echo "-----------------------------------------------------------------------------" >&2

    # Print the count of valid files as the first line to standard output
    echo "$valid_count"
    # Print the list of valid file paths to standard output
    for valid_path in "${valid_config_paths[@]}"; do
        echo "$valid_path"
    done

    # The "Proceeding with valid files..." message is now handled in hourly-backup.sh

}

# Example standalone usage (for testing this script directly):
#if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
#     echo "Testing config_loader.sh..."
#     # Create dummy manifest and included files for testing:
#     mkdir -p /tmp/db_backups_test/conf.d
#     # echo 'include "/tmp/db_backups_test/conf.d/project_a.conf";' > /tmp/db_backups_test/main.manifest
#     # echo 'include "/tmp/db_backups_test/conf.d/project_b.conf"' >> /tmp/db_backups_test/main.manifest
#     # echo 'include /tmp/db_backups_test/conf.d/nonexistent.conf;' >> /tmp/db_backups_test/main.manifest # Test nonexistent
#     # echo "include /tmp/db_backups_test/conf.d/project_c.* ; # Glob test" >> /tmp/db_backups_test/main.manifest # Test glob
#     # echo "  include   /tmp/db_backups_test/conf.d/project_d.conf  " >> /tmp/db_backups_test/main.manifest # Test spacing
#     # echo "# include /tmp/db_backups_test/conf.d/commented.conf" >> /tmp/db_backups_test/main.manifest # Test commented
#     # touch /tmp/db_backups_test/conf.d/project_a.conf
#     # touch /tmp/db_backups_test/conf.d/project_b.conf
#     # touch /tmp/db_backups_test/conf.d/project_c.conf
#     # touch /tmp/db_backups_test/conf.d/project_c.extra
#     # touch /tmp/db_backups_test/conf.d/project_d.conf
#     # mkdir /tmp/db_backups_test/conf.d/is_a_dir.conf # Test directory include
#     # echo 'include /tmp/db_backups_test/conf.d/is_a_dir.conf;' >> /tmp/db_backups_test/main.manifest

#     # echo "--- Expected Output (order may vary before sort -u) ---"
#     # For the above example, expect (after sort -u):
#     # /tmp/db_backups_test/conf.d/project_a.conf
#     # /tmp/db_backups_test/conf.d/project_b.conf
#     # /tmp/db_backups_test/conf.d/project_c.conf
#     # /tmp/db_backups_test/conf.d/project_c.extra
#     # /tmp/db_backups_test/conf.d/project_d.conf
#     # And warnings for nonexistent.conf and is_a_dir.conf

#     # echo "--- Actual Output ---"
#     # get_active_config_paths_from_manifest "/tmp/db_backups_test/main.manifest"
#     # local result=$?
#     # echo "--- Exit code: $result ---"
#     # rm -rf /tmp/db_backups_test
# fi
