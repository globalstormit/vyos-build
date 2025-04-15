#!/bin/bash
# Script to create a local Debian repository for VyOS packages
# This script should be run inside the VyOS build container

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

if [ -z "$VERSION" ]; then
    VERSION=$(grep vyos_branch /vyos/data/defaults.toml | awk -F\" '{print $2}')
    VERSION=${VERSION:-sagitta}
fi

echo "Creating repository for architecture: $ARCH"
echo "Using VyOS version: $VERSION"

# # Clean APT cache
# echo "Cleaning APT cache..."
# sudo rm -rf /var/lib/apt/lists/*
# sudo mkdir -p /var/lib/apt/lists/partial

# sudo gnupg2 --full-gen-key

# Setup repository directory
REPO_DIR="/vyos/local-repo"
sudo rm -rf $REPO_DIR
sudo mkdir -p $REPO_DIR
sudo chown -R $(id -u):$(id -g) $REPO_DIR
cd $REPO_DIR


# Create directory structure
mkdir -p conf
mkdir -p pool/main
mkdir -p dists/$VERSION/main/binary-$ARCH
mkdir -p dists/$VERSION/main/binary-all

# Create reprepro configuration
cat > conf/distributions <<EOF
Origin: VyOS
Label: VyOS
Suite: $VERSION
Codename: $VERSION
Version: 1.4.0
Architectures: $ARCH source
Components: main
Description: VyOS Local Repository
EOF

cat > conf/options <<EOF
basedir .
EOF

# Copy packages to a temporary directory
mkdir -p /tmp/packages
echo "Collecting packages..."
find /vyos/packages -name "*.deb" -exec cp -v {} /tmp/packages/ \;

# Add packages to repository
echo "Adding packages to repository..."
for pkg in /tmp/packages/*.deb; do
    if [ -f "$pkg" ]; then
        reprepro -V --ignore=wrongdistribution includedeb $VERSION "$pkg" || true
    fi
done

# Clean up
rm -rf /tmp/packages

# Verify repository contents
echo "Verifying repository contents..."
reprepro -V list $VERSION

# Create direct symlinks to all .deb files in the pool for the build system
mkdir -p /vyos/packages
find $REPO_DIR/pool -name "*.deb" -exec ln -sf {} /vyos/packages/ \;

# Set proper repository ownership for apt
sudo chown -R root:root $REPO_DIR

# Create basic empty Release file
echo "Creating Release file..."
cat > dists/$VERSION/Release << EOF
Origin: VyOS
Label: VyOS
Suite: $VERSION
Codename: $VERSION
Date: $(date -u +"%a, %d %b %Y %H:%M:%S %Z")
Architectures: $ARCH
Components: main
Description: VyOS Local Repository
EOF

# Create symlink for Release in the main directory
ln -sf dists/$VERSION/Release dists/$VERSION/main/Release

# Generate MD5Sum entries for Release file
echo "MD5Sum:" >> dists/$VERSION/Release
find dists/$VERSION -type f -not -name "Release" -not -name "Release.gpg" | while read -r file; do
    relfile=$(echo $file | sed "s|dists/$VERSION/||")
    md5=$(md5sum $file | cut -d' ' -f1)
    size=$(stat -c%s $file)
    echo " $md5 $size $relfile" >> dists/$VERSION/Release
done

# Create apt source entry
echo "Setting up apt source..."
sudo mkdir -p /etc/apt/sources.list.d
echo "deb [trusted=yes] file:$REPO_DIR $VERSION main" | sudo tee /etc/apt/sources.list.d/local-repo.list

# Update apt
echo "Updating apt..."
sudo apt-get update -o Dir::Etc::sourcelist="sources.list.d/local-repo.list" -o Dir::Etc::sourceparts="-" -o APT::Get::List-Cleanup="0"

echo "Local repository setup complete at $REPO_DIR"
echo "Repository packages:"
find $REPO_DIR/pool -name "*.deb" | sort

# Return to original directory
cd /vyos