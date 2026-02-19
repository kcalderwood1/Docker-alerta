#!/bin/bash

# Script to synchronize dependency versions from DEPENDENCIES file to metadata.hcl

set -e

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

source "$BASE_DIR/scripts/buildHelpers.sh"

DEPENDENCIES_FILE="$BASE_DIR/DEPENDENCIES"
METADATA_FILE="$BASE_DIR/${PACK_PATH}/metadata.hcl"

echo "Reading versions from DEPENDENCIES file..."
echo "============================================"

# Track if any updates were made
updates_made=0

# Read DEPENDENCIES file line by line
while IFS=': ' read -r dep_name dep_version || [[ -n "$dep_name" ]]; do
    # Skip empty lines
    [[ -z "$dep_name" ]] && continue
    
    # Trim whitespace
    dep_name=$(echo "$dep_name" | xargs)
    dep_version=$(echo "$dep_version" | xargs)
    
    # Skip if either is empty
    [[ -z "$dep_name" || -z "$dep_version" ]] && continue
    
    echo ""
    echo "Processing dependency: $dep_name"
    echo "  Expected version: $dep_version"
    
    # Extract current version from metadata.hcl for this dependency
    # Look for the dependency block and extract the ref= value
    current_version=$(grep -A2 "dependency \"$dep_name\"" "$METADATA_FILE" | \
                      grep -oP 'ref=\K[^&"]+' | head -1)
    
    if [[ -z "$current_version" ]]; then
        echo "  Warning: Dependency '$dep_name' not found in metadata.hcl"
        continue
    fi
    
    echo "  Current version:  $current_version"
    
    if [[ "$current_version" == "$dep_version" ]]; then
        echo "  Status: ✓ Versions match, no update needed"
    else
        echo "  Status: ✗ Version mismatch, updating..."
        
        # Update the version in metadata.hcl
        # Use sed to replace the ref= value within the specific dependency block
        sed -i "/dependency \"$dep_name\"/,/^}/ s|ref=[^&\"]*|ref=$dep_version|" "$METADATA_FILE"
        
        # Verify the update
        new_version=$(grep -A2 "dependency \"$dep_name\"" "$METADATA_FILE" | \
                      grep -oP 'ref=\K[^&"]+' | head -1)
        
        if [[ "$new_version" == "$dep_version" ]]; then
            echo "  Result: ✓ Successfully updated to $dep_version"
            updates_made=$((updates_made + 1))
        else
            echo "  Result: ✗ Failed to update version"
            exit 1
        fi
    fi
    
done < "$DEPENDENCIES_FILE"

if [[ -n "$TEAMCITY_VERSION" && $updates_made -gt 0 ]]; then
    gitSetup
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
    gitCheckout "${RELEASE_REPO_NAME}" "${CURRENT_BRANCH}"
    cd checkouts/${RELEASE_REPO_NAME}
    echo "Copy ${METADATA_FILE} to ./${PACK_PATH}/metadata.hcl"
    cp ${METADATA_FILE} ./${PACK_PATH}/metadata.hcl
    echo "Commiting fixed versions..."
    gitCommitAndPush "${RELEASE_REPO_NAME}" "ci: Synchronizing dependency versions"
    cd ../..
fi

echo ""
echo "============================================"
echo "Synchronization complete!"
echo "Total updates made: $updates_made"
