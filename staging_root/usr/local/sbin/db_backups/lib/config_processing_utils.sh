#!/usr/bin/env bash
set -euo pipefail
# =============================================================================
# Script: config_processing_utils.sh
# Purpose: Provides utility functions for setting up and using a temporary SQLite
#          database to validate configuration files and detect duplicates in
#          backup runs.
# Copyright: (c) 2025 Alejandro Capuro Meyer. All rights reserved.
# License: GPL v3 - see LICENSE file for details
# Development: This script was developed with AI assistance (including Gemini,
#              ChatGPT, Claude, Jules, Firebase, and others) under human
#              guidance for architecture, logic design, and project direction.
# File Version: 20250723.155400
# Project Version: 1.0.0
# Project Repository: https://github.com/capuromeyer/db_backups
# Usage: This script is intended to be sourced by other scripts and provides
#        functions for configuration processing and validation.
#
# Notes:
# - This script is not meant for direct execution.
# =============================================================================

# Globals (initialized to avoid unbound variable errors)
declare -a MISSING_OR_UNREADABLE_FILES_REPORT_LINES=()
declare -i TOTAL_CONFIGS_FROM_MANIFEST=0

# ----------------------------------------------------------------------------
# FUNCTION: escape_sql
# Purpose : Escape single quotes in a string for safe SQLite insertion
# ----------------------------------------------------------------------------
escape_sql() {
    local s="$1"
    printf '%s' "$s" | sed "s/'/''/g"
}

# ----------------------------------------------------------------------------
# FUNCTION: setup_temp_sqlite_db
# Purpose : Create a unique temporary SQLite DB file and set caller var
# ----------------------------------------------------------------------------
setup_temp_sqlite_db() {
    local freq="$1" varname="$2" base_dir="/var/cache/db_backups/run_states"
    mkdir -p "$base_dir" || { echo "[LIB_UTILS_ERROR] Cannot create $base_dir" >&2; return 1; }

    local dbpath rand
    dbpath=$(mktemp "${base_dir}/db_run_${freq}_${$}_XXXXXX.sqlite")
    if [[ -z "$dbpath" || ! -w "$dbpath" ]]; then
        rand=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c6)
        dbpath="${base_dir}/db_run_${freq}_${$}_$(date +%s%N)_${rand}.sqlite"
        : > "$dbpath" || { echo "[LIB_UTILS_ERROR] Cannot create fallback DB at $dbpath" >&2; printf -v "$varname" ''; return 1; }
    fi

    sqlite3 "$dbpath" <<SQL
CREATE TABLE IF NOT EXISTS project_configs (
    config_file_path TEXT PRIMARY KEY,
    original_project_name TEXT,
    sanitized_project_name TEXT,
    backup_type TEXT,
    initial_status TEXT NOT NULL,
    final_status TEXT,
    failure_reason TEXT
);
SQL
    if [[ $? -ne 0 ]]; then
        echo "[LIB_UTILS_ERROR] Failed to initialize DB schema" >&2
        rm -f "$dbpath"
        printf -v "$varname" ''
        return 1
    fi

    printf -v "$varname" '%s' "$dbpath"
    return 0
}

# ----------------------------------------------------------------------------
# FUNCTION: insert_initial_records
# Purpose : Insert a single config's validation data into the DB
# ----------------------------------------------------------------------------
insert_initial_records() {
    local db="$1" cfg="$2" orig="$3" sani="$4" btype="$5" istatus="$6" reason="$7"
    local esc_cfg esc_orig esc_sani esc_type esc_status esc_reason
    esc_cfg=$(escape_sql "$cfg")
    esc_orig=$(escape_sql "${orig:-N/A}")
    esc_sani=$(escape_sql "${sani:-N/A}")
    esc_type=$(escape_sql "${btype:-N/A}")
    esc_status=$(escape_sql "${istatus:-N/A}")
    esc_reason=$(escape_sql "${reason:-}")

    sqlite3 "$db" <<SQL 2>/dev/null
INSERT OR IGNORE INTO project_configs(
    config_file_path, original_project_name, sanitized_project_name,
    backup_type, initial_status, final_status, failure_reason
) VALUES (
    '$esc_cfg', '$esc_orig', '$esc_sani',
    '$esc_type', '$esc_status', NULL, '$esc_reason'
);
SQL
    if [[ $? -ne 0 ]]; then echo "[LIB_UTILS_WARN] Failed to insert record for $cfg" >&2; fi
}

# ----------------------------------------------------------------------------
# FUNCTION: mark_duplicate_names
# Purpose : Mark entries whose sanitized_project_name is duplicated
# ----------------------------------------------------------------------------
mark_duplicate_names() {
    local db="$1" dups
    mapfile -t dups < <(sqlite3 -separator $'\n' "$db" \
        "SELECT sanitized_project_name FROM project_configs \
         WHERE initial_status='VALID' AND sanitized_project_name!='' \
         GROUP BY sanitized_project_name HAVING COUNT(*)>1;")
    if (( ${#dups[@]} == 0 )); then return 0; fi

    echo "[LIB_UTILS_WARN] Duplicate sanitized names: ${dups[*]}"
    for name in "${dups[@]}"; do
        local esc_name esc_msg
        esc_name=$(escape_sql "$name")
        esc_msg=$(escape_sql "Duplicate name '$name'")
        sqlite3 "$db" <<SQL
UPDATE project_configs SET
    final_status='INVALID_DUPLICATE_NAME',
    failure_reason='$esc_msg'
WHERE sanitized_project_name='$esc_name' AND initial_status='VALID';
SQL
        if [[ $? -ne 0 ]]; then echo "[LIB_UTILS_WARN] Failed to mark duplicates for $name" >&2; fi
    done
}

# ----------------------------------------------------------------------------
# FUNCTION: populate_db_and_mark_duplicates
# Purpose : Validate each config file and register it, then mark duplicates
# ----------------------------------------------------------------------------
populate_db_and_mark_duplicates() {
    local db="$1" arrname="$2"
    declare -n arr_ref="$arrname"
    TOTAL_CONFIGS_FROM_MANIFEST=${#arr_ref[@]}
    echo "[LIB_UTILS_INFO] Populating DB for ${TOTAL_CONFIGS_FROM_MANIFEST} configs in $db"

    for cfg in "${arr_ref[@]}"; do
        local out status proj type reason sani
        out=$(perform_initial_config_validation "$cfg")
        IFS='|' read -r status proj type reason <<< "$out"
        sani=$(echo "$proj" | sed 's/[^a-zA-Z0-9_.-]/_/g' | sed 's/__*/_/g')
        if [[ "$status" != "VALID" || -z "$sani" ]]; then status='INVALID'; fi
        insert_initial_records "$db" "$cfg" "$proj" "$sani" "$type" "$status" "$reason"
    done
    mark_duplicate_names "$db"
}

# ----------------------------------------------------------------------------
# FUNCTION: generate_validation_report
# Purpose : Print formatted report from DB and missing files
# ----------------------------------------------------------------------------
generate_validation_report() {
    local db="$1"
    echo
    echo "Project Config Validation Summary:"
    echo "------------------------------------------------------------------------------------------------"
    printf "%-45s | %-10s | %-10s | %-20s | %s\n" \
        "Config File Path" "Status" "Type" "Project Name" "Reason/Details"
    echo "------------------------------------------------------------------------------------------------"

    if (( ${#MISSING_OR_UNREADABLE_FILES_REPORT_LINES[@]} > 0 )); then
        for line in "${MISSING_OR_UNREADABLE_FILES_REPORT_LINES[@]}"; do echo "$line"; done
    fi

    local rows
    rows=$(sqlite3 -separator '|' "$db" \
        "SELECT config_file_path, COALESCE(final_status, initial_status) AS status, backup_type, original_project_name, failure_reason \
         FROM project_configs ORDER BY config_file_path;") || {
        echo "[LIB_UTILS_ERROR] Failed to query DB for report." >&2; return 1
    }

    while IFS='|' read -r path status type proj reason; do
        printf "%-45s | %-10s | %-10s | %-20s | %s\n" \
            "$path" "$status" "$type" "$proj" "${reason:-None}"
    done <<< "$rows"

    echo "------------------------------------------------------------------------------------------------"
    echo "Total configs in manifest: $TOTAL_CONFIGS_FROM_MANIFEST"
    echo "Configurations valid for execution: $(echo "$rows" | grep -c '|VALID|')"
    echo "------------------------------------------------------------------------------------------------"
    return 0
}
