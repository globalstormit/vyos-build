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

# Generate Packages.gz
echo "Generating Packages.gz..."
cd "$REPO_PATH"
sudo dpkg-scanpackages . /dev/null | gzip -9c | sudo tee Packages.gz > /dev/null

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

# Generate Release with Codename included
sudo apt-ftparchive -c "$TMP_CONF" release . | sudo tee Release > /dev/null

# Clean up the temp config file
rm "$TMP_CONF"

# Fix ownership (important if inside a container)
echo "Fixing permissions..."
sudo chown -R "$HOST_UID:$HOST_GID" "$REPO_BASE"

# Add repo to APT
echo "Adding to APT sources..."
echo "deb [trusted=yes allow-insecure=yes allow-downgrade-to-insecure=yes] file:$REPO_BASE $DIST main" | sudo tee /etc/apt/sources.list.d/local-vyos.list
mkdir -p /vyos/data/live-build-config/includes.chroot/etc/apt/sources.list.d/
cat <<EOF > /vyos/data/live-build-config/includes.chroot/etc/apt/sources.list.d/local-vyos.list
deb [trusted=yes allow-insecure=yes allow-downgrade-to-insecure=yes] file:/vyos/local-repo sagitta main
EOF

echo FFFFFFFFFFUUUUUUUUUUUUUU
echo FFFFFFFFFFUUUUUUUUUUUUUU
echo FFFFFFFFFFUUUUUUUUUUUUUU
cat /etc/apt/sources.list.d/local-vyos.list
echo FFFFFFFFFFUUUUUUUUUUUUUU
echo FFFFFFFFFFUUUUUUUUUUUUUU
echo FFFFFFFFFFUUUUUUUUUUUUUU
# echo "deb [trusted=yes] file:/vyos/local-repo sagitta main" | sudo tee /etc/apt/sources.list.d/local-vyos.list

# Update APT index
echo "Running apt-get update..."
sudo apt-get update

mkdir -p /vyos/data/live-build-config/includes.chroot/vyos/local-repo
sudo mount -o bind /vyos/local-repo /vyos/data/live-build-config/includes.chroot/vyos/local-repo
echo "Local repo ready to go!"