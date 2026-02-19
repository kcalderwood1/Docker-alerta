#!/bin/bash

SERVICE_NAME="$1"
VERSION="$2"
RELEASE_BRANCH="$3"

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
source "${BASE_DIR}/scripts/buildHelpers.sh"

if [[ -n "$TEAMCITY_VERSION" ]]; then
    # Update service version
    gitSetup
    source "./scripts/buildHelpers.sh"
    gitCheckout "${RELEASE_REPO_NAME}" "${RELEASE_BRANCH}"
    cd "checkouts/${RELEASE_REPO_NAME}"
    git pull

    ./scripts/updateVersion.sh "${SERVICE_NAME}" "${VERSION}"

    echo "Commiting updated version..."
    gitCommitAndPush "$RELEASE_REPO_NAME" "ci: Updated dependency - ${SERVICE_NAME}=${VERSION}"
else
    echo "This script should be run from Teamcity CI/CD pipeline"
    exit 1
fi
