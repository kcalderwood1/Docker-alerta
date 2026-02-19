#!/bin/bash
# build script that is ran from Teamcity pipeline

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
source "$BASE_DIR/scripts/buildHelpers.sh"

if [[ -n "$TEAMCITY_VERSION" ]]; then
    # Try to run nomad-pack dependency vendoring
    cd "$BASE_DIR/${PACK_PATH}"
    nomad-pack deps vendor
else
    echo "This script should be run from Teamcity CI/CD pipeline"
    exit 1
fi
