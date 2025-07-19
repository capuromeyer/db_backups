#!/bin/bash
# -----------------------------------------------------------------------------
# Script: ttl_parser.sh
# Purpose: Parses human-friendly TTL (Time To Live) strings (e.g., "7d", "4w")
#          into an equivalent value in total minutes.
# Developed by: Alejandro Capuro (Project Lead & Logic Design)
# Implemented by: Jules (AI Assistant, under guidance)
# Copyright: (c) 2025 Alejandro Capuro. All rights reserved.
# File Version: 20250703.100000 # YYYYMMDD.HHMMSS
# Project Version: 1.0.0
#
# Usage:
#   source this script
#   minutes=$(parse_human_ttl_to_minutes "7d")
#   if [ "$minutes" == "INVALID_TTL" ]; then echo "Error parsing"; fi
#
# Notes:
#   - Intended to be sourced by preflight.sh or other scripts.
#   - Uses approximations: 1M = 31 days, 1y = 365 days for TTL calculations.
# -----------------------------------------------------------------------------

# Function to parse a human-readable TTL string and convert it to minutes.
# Arguments:
#   $1: human_ttl_string (string) - e.g., "60m", "24h", "7d", "4w", "6M", "1y"
# Echos:
#   Total minutes as an integer on success.
#   The string "INVALID_TTL" on failure.
# Returns:
#   0 on success, 1 on parsing failure (caller should check echoed string).
parse_human_ttl_to_minutes() {
    local human_ttl_string="$1"
    local number_part
    local suffix_part
    local total_minutes

    if [ -z "$human_ttl_string" ]; then
        echo "Error: TTL string cannot be empty." >&2
        echo "INVALID_TTL"
        return 1
    fi

    # Regex to extract number and suffix. Allows for optional space.
    # ^([0-9]+)\s*([mhdMyw])$
    if [[ "$human_ttl_string" =~ ^([0-9]+)[[:space:]]*([mhdMyw])$ ]]; then
        number_part="${BASH_REMATCH[1]}"
        suffix_part="${BASH_REMATCH[2]}"
    else
        echo "Error: Invalid TTL format '$human_ttl_string'. Expected <number><suffix> (e.g., '7d', '24h')." >&2
        echo "Supported suffixes: m (minutes), h (hours), d (days), w (weeks), M (months), y (years)." >&2
        echo "INVALID_TTL"
        return 1
    fi

    if ! [[ "$number_part" =~ ^[0-9]+$ ]] || [ "$number_part" -lt 0 ]; then # Allow 0 for "keep forever" if desired by caller
        echo "Error: Invalid numeric part '$number_part' in TTL '$human_ttl_string'. Must be a non-negative integer." >&2
        echo "INVALID_TTL"
        return 1
    fi

    # Handle 0 explicitly, as it means "keep forever" or "no auto-deletion"
    if [ "$number_part" -eq 0 ]; then
        echo "0" # 0 minutes means no TTL based deletion by some interpretations
        return 0
    fi

    case "$suffix_part" in
        m) # Minutes
            total_minutes=$((number_part))
            ;;
        h) # Hours
            total_minutes=$((number_part * 60))
            ;;
        d) # Days
            total_minutes=$((number_part * 60 * 24))
            ;;
        w) # Weeks
            total_minutes=$((number_part * 60 * 24 * 7))
            ;;
        M) # Months (approx. 31 days for TTL calculation)
            total_minutes=$((number_part * 60 * 24 * 31))
            ;;
        y) # Years (approx. 365 days)
            total_minutes=$((number_part * 60 * 24 * 365))
            ;;
        *)
            # This case should not be reached if regex is correct, but as a safeguard
            echo "Error: Unknown TTL suffix '$suffix_part' in '$human_ttl_string'." >&2
            echo "INVALID_TTL"
            return 1
            ;;
    esac

    echo "$total_minutes"
    return 0
}

# Example Usage (if script is run directly for testing)
# if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
#     echo "Testing ttl_parser.sh..."
#     test_cases=("60m" "1h" "24h" "1d" "7d" "1w" "4w" "1M" "6M" "1y" "0m" "0d" "100" "10d " " 10d" "10 d")
#     expected_results=(60 60 1440 1440 10080 10080 40320 43200 259200 525600 0 0 "INVALID_TTL" "INVALID_TTL" "INVALID_TTL" "INVALID_TTL")
#     # Note: My regex will fail "10d ", " 10d", "10 d" currently. It expects number directly followed by letter, optional space removed by regex.
#     # Updated regex ^([0-9]+)[[:space:]]*([mhdMyw])$ handles optional space.
#
#     i=0
#     for tc in "${test_cases[@]}"; do
#         echo -n "Input: '$tc' -> "
#         result=$(parse_human_ttl_to_minutes "$tc")
#         if [ $? -eq 0 ] && [ "$result" != "INVALID_TTL" ]; then
#             echo "Parsed: $result minutes. Expected: ${expected_results[$i]}"
#             if [ "$result" -ne "${expected_results[$i]}" ]; then echo "   MISMATCH!"; fi
#         else
#             echo "Result: $result (as expected for invalid or error). Expected: ${expected_results[$i]}"
#             if [ "$result" != "${expected_results[$i]}" ]; then echo "   MISMATCH!"; fi
#         fi
#         i=$((i + 1))
#     done
#
#     echo "Testing invalid inputs:"
#     parse_human_ttl_to_minutes "10s" # Invalid suffix
#     parse_human_ttl_to_minutes "d10" # Invalid format
#     parse_human_ttl_to_minutes ""    # Empty
#     parse_human_ttl_to_minutes "  "  # Blank
#     parse_human_ttl_to_minutes "10 d" # Space before suffix (now handled by regex)
# fi
