#!/bin/bash

# Script to report dependency versions from DEPENDENCIES file.

set -e

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

DEPENDENCIES_FILE="$BASE_DIR/DEPENDENCIES"

echo "Dependency versions (from DEPENDENCIES)..."
echo "============================================"

if [[ ! -f "$DEPENDENCIES_FILE" ]]; then
    echo "No DEPENDENCIES file found at $DEPENDENCIES_FILE"
    exit 1
fi

while IFS=': ' read -r dep_name dep_version || [[ -n "$dep_name" ]]; do
    [[ -z "$dep_name" ]] && continue
    dep_name=$(echo "$dep_name" | xargs)
    dep_version=$(echo "$dep_version" | xargs)
    [[ -z "$dep_name" || -z "$dep_version" ]] && continue
    echo "  $dep_name: $dep_version"
done < "$DEPENDENCIES_FILE"

echo "============================================"
echo "DEPENDENCIES is the source of truth for release versions."
