#!/bin/bash

# Script to update service version in DEPENDENCIES and metadata.hcl files
# Usage: ./updateVersion.sh <service_name> <version>

set -e

SERVICE_NAME="$1"
VERSION="$2"

# Function to display usage
usage() {
    echo "Usage: $0 <service_name> <version>"
    echo ""
    echo "Arguments:"
    echo "  service_name  Name of the service to update (e.g., lucera-alerta, lucera-alerta-plugins, lucera-alerta-ui)"
    echo "  version       New version to set (e.g., v0.1.7)"
    echo ""
    echo "Example:"
    echo "  $0 lucera-alerta v0.1.7"
    exit 1
}

# Check if both arguments are provided
if [ $# -ne 2 ]; then
    echo "Error: Both service name and version are required."
    usage
fi

# Validate version format (should start with 'v' followed by semver)
if [[ ! "$VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "ERROR: Version '$VERSION' does not match expected format (e.g., v0.1.7)"
    exit 1
fi

# Get the base dir (repo root when run from repo root or scripts/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
source "$BASE_DIR/scripts/buildHelpers.sh"
echo "Working directory: ${BASE_DIR}"

DEPENDENCIES_FILE="$BASE_DIR/DEPENDENCIES"
METADATA_FILE="$BASE_DIR/${PACK_PATH}/metadata.hcl"

# Check if service exists in DEPENDENCIES file
if ! grep -q "^${SERVICE_NAME}:" "$DEPENDENCIES_FILE"; then
    echo "Error: Service '$SERVICE_NAME' not found in DEPENDENCIES file"
    echo ""
    echo "Available services:"
    awk -F: '{print "  - " $1}' "$DEPENDENCIES_FILE"
    exit 1
fi

# Get current version from DEPENDENCIES
CURRENT_VERSION=$(grep "^${SERVICE_NAME}:" "$DEPENDENCIES_FILE" | awk -F': ' '{print $2}')
echo "Updating $SERVICE_NAME from $CURRENT_VERSION to $VERSION"

# Update DEPENDENCIES file
sed -i "s/^${SERVICE_NAME}: .*/${SERVICE_NAME}: ${VERSION}/" "$DEPENDENCIES_FILE"
echo "Updated DEPENDENCIES file"

# Update metadata.hcl file - update the ref= parameter in the dependency block
# Match the dependency block for the service and update the ref parameter
sed -i "/dependency \"${SERVICE_NAME}\"/,/^}/s/ref=[^&]*/ref=${VERSION}/" "$METADATA_FILE"
echo "Updated metadata.hcl file"

echo ""
echo "Successfully updated $SERVICE_NAME to $VERSION"
echo ""
echo "Changes made:"
echo "  DEPENDENCIES: ${SERVICE_NAME}: ${VERSION}"
grep "dependency \"${SERVICE_NAME}\"" -A 3 "$METADATA_FILE" | grep "source"
