#!/bin/bash
# Script to create a local Debian repository for VyOS packages
# This script should be run inside the VyOS build container

set -e

echo "Setting up local package repository..."
mkdir -p /vyos/local-repo
cd /vyos/local-repo

# Print current user for debugging
echo "Current UID/GID: $(id -u)/$(id -g)"

# Determine architecture and version from build configuration
if [ -f "/vyos/.env" ]; then
    source /vyos/.env
fi

# If not set in .env, get from defaults.toml
if [ -z "$ARCH" ]; then
    ARCH=$(grep architecture /vyos/data/defaults.toml | awk -F\" '{print $2}')
    ARCH=${ARCH:-amd64}
fi

if [ -z "$VERSION" ]; then
    VERSION=$(grep vyos_branch /vyos/data/defaults.toml | awk -F\" '{print $2}')
    VERSION=${VERSION:-sagitta}
fi

echo "Creating repository for architecture: $ARCH"
echo "Using VyOS version: $VERSION"

# Create the standard repository structure
echo "Creating repository structure..."
mkdir -p conf dists/${VERSION}/main/binary-${ARCH}

# Create repository configuration
cat > conf/distributions << EOF
Origin: VyOS
Label: VyOS
Suite: ${VERSION}
Codename: ${VERSION}
Architectures: ${ARCH}
Components: main
Description: VyOS local package repository for ${VERSION}/${ARCH}
EOF

# Use reprepro to manage the repository
echo "Adding packages to repository..."
if command -v reprepro &>/dev/null; then
    # Clear any existing packages from the repository
    reprepro -b . clearvanished || true
    
    # Add all .deb packages to the repository
    for deb in *.deb; do
        if [ -f "$deb" ]; then
            echo "  Adding $deb to repository"
            reprepro -b . includedeb ${VERSION} "$deb" || true
        fi
    done
    
    # Show repository information
    echo "Repository information:"
    reprepro -b . list ${VERSION} || true
else
    echo "Error: reprepro not found."
    exit 1
fi

# Verify the repository
if [ -d "dists/${VERSION}" ]; then
    echo "Local repository created successfully at /vyos/local-repo"
    echo "Repository contains the following packages:"
    ls -la *.deb 2>/dev/null || echo "No packages found"
else
    echo "ERROR: Failed to create repository structure."
    exit 1
fi
