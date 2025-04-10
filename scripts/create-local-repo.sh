#!/bin/bash
# Script to create a local Debian repository for VyOS packages
# This script should be run inside the VyOS build container

set -e

echo "Setting up local package repository..."
cd /vyos/local-packages

# Ensure we have the necessary tools
apt-get update
apt-get install -y dpkg-dev

# Create the package index
echo "Creating package index..."
dpkg-scanpackages . > Packages
gzip -k Packages

echo "Local repository created successfully at /vyos/local-packages"
echo "Repository contains $(grep -c "^Package:" Packages) packages"
