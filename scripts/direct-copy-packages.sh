#!/bin/bash
set -e

echo "BYPASSING REPOSITORY MECHANISM - Copying packages directly to live-build structure"

# Source packages directory
PKG_DIR="/vyos/packages"

# Destination is the live-build packages directory
LB_PKG_DIR="/vyos/build/config/packages.chroot"

# Create destination directory
mkdir -p "$LB_PKG_DIR"

# Copy all .deb packages directly
find "$PKG_DIR" -name "*.deb" -exec cp -v {} "$LB_PKG_DIR/" \;

echo "Packages copied directly to live-build structure at $LB_PKG_DIR"
ls -la "$LB_PKG_DIR"
echo "Done."
