#!/bin/bash
set -e

echo "Creating local package repository..."

# Get host UID/GID for ownership fix later
HOST_UID=$(stat -c "%u" /vyos)
HOST_GID=$(stat -c "%g" /vyos)

echo "Current UID/GID: $(id -u)/$(id -g)"

# Get arch and dist from .env or defaults
if [ -f "/vyos/.env" ]; then
    source /vyos/.env
fi

if [ -z "$ARCH" ]; then
    ARCH=$(grep architecture /vyos/data/defaults.toml | awk -F\" '{print $2}')
    ARCH=${ARCH:-amd64}
fi

if [ -z "$DIST" ]; then
    DIST=$(grep vyos_branch /vyos/data/defaults.toml | awk -F\" '{print $2}')
    DIST=${DIST:-sagitta}
fi

echo "Creating repo for ARCH: $ARCH, DIST: $DIST"

# Paths
PKG_DIR="/vyos/packages"
REPO_BASE="/vyos/local-repo"
REPO_PATH="$REPO_BASE/dists/$DIST/main/binary-$ARCH"

# Clean repo and recreate layout
echo "Cleaning old repo..."
sudo rm -rf "$REPO_BASE"
sudo mkdir -p "$REPO_PATH"

# Copy packages
echo "Collecting .deb packages..."
sudo find "$PKG_DIR" -name "*.deb" -exec cp -v {} "$REPO_PATH" \;

# Generate Packages file first
echo "Generating Packages file..."
cd "$REPO_PATH"
sudo dpkg-scanpackages . /dev/null > Packages
sudo gzip -9c Packages > Packages.gz

# Go to the distribution directory to create Release file
echo "Generating Release file..."
cd "$REPO_BASE/dists/$DIST"

# Create a simple but effective Release file - the key is that it must exist!
cat <<EOF | sudo tee Release
Origin: VyOS Local
Label: VyOS
Suite: $DIST
Codename: $DIST
Date: $(date -R)
Architectures: $ARCH
Components: main
Description: Local VyOS repository
EOF

# Fix ownership
echo "Fixing permissions..."
sudo chown -R "$HOST_UID:$HOST_GID" "$REPO_BASE"

# Update APT to use our repo
echo "Adding repo to APT sources..."
echo "deb [trusted=yes allow-insecure=yes allow-downgrade-to-insecure=yes] file:$REPO_BASE $DIST main" | sudo tee /etc/apt/sources.list.d/local-vyos.list

# Update APT index
echo "Running apt-get update..."
sudo apt-get update -o Acquire::AllowInsecureRepositories=true

# Copy config to lb
mkdir -p /vyos/build/config/archives/
echo "deb [trusted=yes allow-insecure=yes allow-downgrade-to-insecure=yes]file:$REPO_BASE $DIST main" | sudo tee /vyos/build/config/archives/vyos.list.chroot

# Debug output
echo "DEBUG: Repository structure:"
ls -la "$REPO_BASE/dists/$DIST/"
echo "Release file content:"
cat "$REPO_BASE/dists/$DIST/Release"

echo "Local repo ready to go!"