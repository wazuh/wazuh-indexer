#!/bin/bash

# =========================
# RPM Changelog Checker
# =========================
# Validates the %changelog section of the RPM spec file. Since rpm 4.15,
# rpmbuild only logs an error when the entries are not in descending
# chronological order and silently drops every entry from that point on, so a
# broken changelog does not fail the build.
#
# Every entry must:
#   - have a valid date whose weekday matches the day of the month.
#   - not be newer than the entry above it.
#   - be followed by the release notes link of its version.
#
# It takes one optional argument:
# 1. The path to the RPM spec file (defaults to the wazuh-indexer one)

set -euo pipefail

export LC_ALL=C

SPEC_FILE="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/distribution/packages/src/rpm/wazuh-indexer.rpm.spec}"
RELEASE_NOTES_URL="https://documentation.wazuh.com/current/release-notes"
# * Wed Jul 01 2026 support <info@wazuh.com> - 4.14.6
HEADER_REGEX='^\* ([A-Z][a-z]{2}) ([A-Z][a-z]{2}) ([0-9]{2}) ([0-9]{4}) .+ - ([0-9]+\.[0-9]+\.[0-9]+)$'
ERRORS=0

if date --version >/dev/null 2>&1; then
    GNU_DATE=true
else
    GNU_DATE=false
fi

# ====
# Report a problem in the spec file
# Arguments:
#   $1 - line number
#   $2 - message
# ====
function report() {
    echo "${SPEC_FILE}:$1: $2" >&2
    ERRORS=$((ERRORS + 1))
}

# ====
# Print the number of a month abbreviation (Jan -> 01)
# Arguments:
#   $1 - month abbreviation
# ====
function month_number() {
    case "$1" in
    Jan) echo "01" ;;
    Feb) echo "02" ;;
    Mar) echo "03" ;;
    Apr) echo "04" ;;
    May) echo "05" ;;
    Jun) echo "06" ;;
    Jul) echo "07" ;;
    Aug) echo "08" ;;
    Sep) echo "09" ;;
    Oct) echo "10" ;;
    Nov) echo "11" ;;
    Dec) echo "12" ;;
    *) return 1 ;;
    esac
}

# ====
# Print the weekday abbreviation of a date, failing if the date does not exist
# Arguments:
#   $1 - date in YYYY-MM-DD format
# ====
function weekday_of() {
    local iso_date="$1"
    local output

    if $GNU_DATE; then
        # GNU date (Linux)
        output=$(date -d "$iso_date" +"%Y-%m-%d %a" 2>/dev/null) || return 1
    else
        # BSD date (macOS)
        output=$(date -jf "%Y-%m-%d" "$iso_date" +"%Y-%m-%d %a" 2>/dev/null) || return 1
    fi

    # BSD date rolls invalid dates over (Feb 30 -> Mar 02) instead of failing
    if [[ "${output% *}" != "$iso_date" ]]; then
        return 1
    fi

    echo "${output#* }"
}

# ====
# Validate the %changelog section
# Arguments:
#   $1 - spec file
# ====
function check_changelog() {
    local spec_file="$1"
    local in_changelog=false
    local entries=0
    local line_number=0
    local line
    local expected_link=""
    local previous_date=""
    local previous_version=""
    local weekday month day year version month_num iso_date actual_weekday

    if [[ ! -f "$spec_file" ]]; then
        echo "Error: $spec_file not found" >&2
        exit 1
    fi

    while IFS= read -r line || [[ -n "$line" ]]; do
        line_number=$((line_number + 1))

        if ! $in_changelog; then
            if [[ "$line" == "%changelog" ]]; then
                in_changelog=true
            fi
            continue
        fi

        # The line right after an entry header must be its release notes link
        if [[ -n "$expected_link" ]]; then
            if [[ "$line" != "$expected_link" ]]; then
                report "$line_number" "expected '$expected_link'"
            fi
            expected_link=""
        fi

        if [[ "$line" != \** ]]; then
            continue
        fi

        entries=$((entries + 1))
        if ! [[ "$line" =~ $HEADER_REGEX ]]; then
            report "$line_number" "malformed entry header '$line'"
            continue
        fi
        weekday="${BASH_REMATCH[1]}"
        month="${BASH_REMATCH[2]}"
        day="${BASH_REMATCH[3]}"
        year="${BASH_REMATCH[4]}"
        version="${BASH_REMATCH[5]}"
        expected_link="- More info: ${RELEASE_NOTES_URL}/release-${version//./-}.html"

        if ! month_num=$(month_number "$month") || ! actual_weekday=$(weekday_of "$year-$month_num-$day"); then
            report "$line_number" "invalid date '$month $day $year' ($version)"
            continue
        fi
        iso_date="$year-$month_num-$day"

        if [[ "$weekday" != "$actual_weekday" ]]; then
            report "$line_number" "'$weekday $month $day $year' should be '$actual_weekday $month $day $year' ($version)"
        fi

        if [[ -n "$previous_date" && "$iso_date" > "$previous_date" ]]; then
            report "$line_number" "$version ($iso_date) is newer than the entry above it, $previous_version ($previous_date)"
        fi
        previous_date="$iso_date"
        previous_version="$version"
    done <"$spec_file"

    if [[ -n "$expected_link" ]]; then
        report "$line_number" "expected '$expected_link'"
    fi

    if ! $in_changelog; then
        report "$line_number" "%changelog section not found"
    fi

    if [[ $ERRORS -gt 0 ]]; then
        echo "Found $ERRORS problem(s) in the %changelog of $spec_file" >&2
        exit 1
    fi

    echo "The %changelog of $spec_file is valid ($entries entries)"
}

check_changelog "$SPEC_FILE"
