#!/bin/bash
set -e

echo "Creating local package repository..."
echo "DEBUG: Current directory: $(pwd)"

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
POOL_DIR="$REPO_BASE/pool/main"
REPO_PATH="$REPO_BASE/dists/$DIST/main/binary-$ARCH"

# Clean repo and recreate layout
echo "Cleaning old repo..."
sudo rm -rf "$REPO_BASE"
sudo mkdir -p "$POOL_DIR"
sudo mkdir -p "$REPO_PATH"

# Copy packages to pool directory first
echo "Collecting .deb packages to pool..."
sudo find "$PKG_DIR" -name "*.deb" -exec cp -v {} "$POOL_DIR" \;

# Create a symlink from the repo path to the pool directory
echo "Creating symlink from $REPO_PATH to $POOL_DIR"
cd "$REPO_PATH"
sudo ln -sf $POOL_DIR/* .

# Generate Packages and Packages.gz files
echo "Generating Packages files..."
cd "$REPO_PATH"
sudo dpkg-scanpackages -m . > Packages
sudo gzip -9c Packages > Packages.gz

# Generate proper Release file
echo "Generating Release file..."
cd "$REPO_BASE/dists/$DIST"

# Use a temp file for config in a location we CAN write to
TMP_CONF=$(mktemp)

cat <<EOF > "$TMP_CONF"
APT::FTPArchive::Release {
  Codename "$DIST";
  Origin "Local";
  Label "Local";
  Architectures "$ARCH";
  Components "main";
};
EOF

# Generate Release file with correct Codename
sudo apt-ftparchive -c "$TMP_CONF" release . | sudo tee Release > /dev/null

echo "DEBUG: Repository structure:"
sudo find "$REPO_BASE" -type f | sort

# Fix ownership (important if inside a container)
echo "Fixing permissions..."
sudo chown -R "$HOST_UID:$HOST_GID" "$REPO_BASE"

# Add repo to APT
echo "Adding to APT sources..."
echo "deb [trusted=yes] file:$REPO_BASE $DIST main" | sudo tee /etc/apt/sources.list.d/local-vyos.list

# Create a clean reference for the live-build chroot
mkdir -p /vyos/data/live-build-config/includes.chroot/etc/apt/sources.list.d/
echo "deb [trusted=yes] file:$REPO_BASE $DIST main" | sudo tee /vyos/data/live-build-config/includes.chroot/etc/apt/sources.list.d/local-vyos.list

# Update APT index to verify the repository works
echo "Running apt-get update to verify repository..."
sudo apt-get update -o Acquire::AllowInsecureRepositories=true

# Now let's make ABSOLUTELY SURE everything is ready for the build process
echo "DEBUG: Repository information:"
echo "Repository base: $REPO_BASE"
echo "Repository path: $REPO_PATH"
ls -la "$REPO_BASE/dists/$DIST/"
echo "Release file contents:"
cat "$REPO_BASE/dists/$DIST/Release"
echo "APT sources list:"
cat /etc/apt/sources.list.d/local-vyos.list

echo "Local repo ready to go!"