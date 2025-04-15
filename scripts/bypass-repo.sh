#!/bin/bash
set -e

echo "Bypassing repository mechanism completely..."

# Modify defaults.toml to use known working mirror
sed -i 's|file:/vyos/local-repo|https://packages.vyos.net/repositories/current|g' /vyos/data/defaults.toml
echo "Modified defaults.toml to use official VyOS repository"

# Create direct package inclusion directory
mkdir -p /vyos/build/config/packages.chroot/
find /vyos/packages -name "*.deb" -exec cp -v {} /vyos/build/config/packages.chroot/ \;
echo "Copied packages directly to packages.chroot directory for direct inclusion"

# Set necessary environment variables
# This is the key fix - it avoids the need for repository configuration
export DISABLE_VYOS_MIRROR=true

echo "Repository bypass complete - packages will be included directly from packages.chroot"
