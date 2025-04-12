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

# Clean up any existing repository files to avoid conflicts
echo "Cleaning up existing repository structure..."
rm -rf dists pool conf db

# Create basic repository structure
echo "Creating repository structure..."
mkdir -p pool/main
mkdir -p dists/${VERSION}/main/binary-${ARCH}

# Copy all built packages to the pool directory
echo "Copying packages to repository pool..."
for deb in *.deb; do
    if [ -f "$deb" ]; then
        echo "  Adding $deb to pool"
        cp -f "$deb" pool/main/
    fi
done

# Generate the Packages file
echo "Generating Packages file..."
(cd pool/main && dpkg-scanpackages . /dev/null > ../../dists/${VERSION}/main/binary-${ARCH}/Packages)
gzip -9cf dists/${VERSION}/main/binary-${ARCH}/Packages > dists/${VERSION}/main/binary-${ARCH}/Packages.gz

# Generate the Release file
echo "Generating Release file..."
cat > dists/${VERSION}/Release << EOF
Origin: VyOS
Label: VyOS
Suite: ${VERSION}
Codename: ${VERSION}
Date: $(date -u +"%a, %d %b %Y %H:%M:%S UTC")
Architectures: ${ARCH}
Components: main
Description: VyOS Local Repository for ${VERSION}/${ARCH}
EOF

# Generate hash information and append to the Release file
(
  cd dists/${VERSION}
  echo "MD5Sum:" >> Release
  find main -type f -exec md5sum {} \; | sed 's/  / /g' >> Release
  echo "SHA256:" >> Release
  find main -type f -exec sha256sum {} \; | sed 's/  / /g' >> Release
)

# Create sources.list entry
echo "Creating APT source list entry..."
mkdir -p /etc/apt/sources.list.d/
echo "deb [trusted=yes] file:///vyos/local-repo ${VERSION} main" > /etc/apt/sources.list.d/local-repo.list

# Verify the repository structure
echo "Verifying repository structure:"
find /vyos/local-repo -type f | sort

# Update APT to recognize the new repository
echo "Updating APT to recognize the local repository..."
apt-get update -o Dir::Etc::sourcelist="sources.list.d/local-repo.list" -o Dir::Etc::sourceparts="-" -o APT::Get::List-Cleanup="0"

# Verify the repository
if [ -f "dists/${VERSION}/Release" ] && [ -d "pool/main" ]; then
    echo "Local repository created successfully at /vyos/local-repo"
    echo "Repository structure:"
    find . -type f -not -path "*/\.*" | sort
    
    echo "Repository contains the following packages:"
    find pool/main -name "*.deb" -exec basename {} \; || echo "No packages found"
else
    echo "ERROR: Failed to create repository structure."
    exit 1
fi
