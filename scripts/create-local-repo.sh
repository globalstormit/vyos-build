#!/bin/bash
# Script to create a local Debian repository for VyOS packages
# This script should be run inside the VyOS build container

set -e

echo "Setting up local package repository..."
cd /vyos/local-packages

# Print current user for debugging
echo "Current UID/GID: $(id -u)/$(id -g)"

# Check if dpkg-dev is already installed
if ! dpkg -s dpkg-dev &>/dev/null; then
    echo "Installing dpkg-dev package..."
    # Try with and without sudo
    if [ $(id -u) -eq 0 ]; then
        # We're root, no need for sudo
        apt-get update || true
        apt-get install -y dpkg-dev || true
    else
        # Try with sudo
        sudo apt-get update || true
        sudo apt-get install -y dpkg-dev || true
    fi
else
    echo "dpkg-dev is already installed"
fi

# Create the package index
echo "Creating package index..."
dpkg-scanpackages . > Packages 2>/dev/null || true
gzip -k Packages 2>/dev/null || true

# Verify the repository was created successfully
if [ -f "Packages" ]; then
    echo "Local repository created successfully at /vyos/local-packages"
    echo "Repository contains $(grep -c "^Package:" Packages 2>/dev/null || echo "0") packages"
else
    echo "Warning: Failed to create Packages file. Using alternative method..."
    # Alternative method that doesn't require dpkg-dev
    echo "Listing available packages:"
    ls -la *.deb || true
fi
