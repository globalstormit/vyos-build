#!/bin/bash

set -e

echo "Creating local package repository..."

# Make sure the directory is owned by the host user
HOST_UID=$(stat -c "%u" /vyos)
HOST_GID=$(stat -c "%g" /vyos)

# Print current user for debugging
echo "Current UID/GID: $(id -u)/$(id -g)"

# Determine architecture and version
if [ -f "/vyos/.env" ]; then
    source /vyos/.env
fi

# If not set in .env, get from defaults.toml
if [ -z "$ARCH" ]; then
    ARCH=$(grep architecture /vyos/data/defaults.toml | awk -F\" '{print $2}')
    ARCH=${ARCH:-amd64}
fi

if [ -z "$DIST" ]; then
    DIST=$(grep vyos_branch /vyos/data/defaults.toml | awk -F\" '{print $2}')
    DIST=${DIST:-sagitta}
fi

echo "Creating repository for architecture: $ARCH"
echo "Using VyOS version: $VERSION"

# Define base paths
PKG_DIR="/packages"  # Where your .deb files are
REPO_BASE="/vyos/local-repo"
REPO_PATH="$REPO_BASE/dists/$DIST/main/binary-$ARCH"

# Clean up and create required directory structure
sudo rm -rf "$REPO_BASE"
sudo mkdir -p "$REPO_PATH"

# Copy packages to a temporary directory
echo "Collecting packages..."
sudo find /vyos/packages -name "*.deb" -exec cp -v {} $REPO_PATH \;

# Generate Packages.gz
cd "$REPO_PATH"
sudo dpkg-scanpackages . /dev/null | gzip -9c > Packages.gz

# Create a minimal Release file
sudo cat > "$REPO_BASE/dists/$DIST/Release" <<EOF
Archive: $DIST
Component: main
Origin: Local
Label: Local
Architecture: $ARCH
EOF

echo "✅ Local APT repository created at $REPO_BASE"

echo "deb [trusted=yes] file:$REPO_BASE $DIST main" | sudo tee /etc/apt/sources.list.d/local-vyos.list

sudo apt-get update