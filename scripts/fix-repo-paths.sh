#!/bin/bash
set -e

echo "Fixing repository paths for live-build environment..."

# First, let's examine what we're working with
echo "Current directory structure:"
ls -la /vyos/build/
ls -la /vyos/local-repo/ || echo "No local-repo directory found"

# Ensure the repository structure exists in the build environment
mkdir -p /vyos/build/local-repo/dists/sagitta/main/binary-amd64/

# Copy the actual repository contents
echo "Copying repository to build directory..."
cp -rv /vyos/local-repo/dists/sagitta/* /vyos/build/local-repo/dists/sagitta/

# Create the APT configuration for the chroot environment
mkdir -p /vyos/build/config/hooks/normal/
cat > /vyos/build/config/hooks/normal/01-setup-local-repo.chroot <<'EOF'
#!/bin/bash
echo "Setting up local repository in chroot environment..."
# Create a direct APT source entry that doesn't rely on mounted paths
echo "deb [trusted=yes] file:/local-repo sagitta main" > /etc/apt/sources.list.d/local-vyos.list
# Allow unsigned packages
echo "APT::Get::AllowUnauthenticated true;" > /etc/apt/apt.conf.d/99allow-unauth
apt-get update || true
EOF

chmod +x /vyos/build/config/hooks/normal/01-setup-local-repo.chroot

# Also copy the packages directly to packages.chroot as a fallback
mkdir -p /vyos/build/config/packages.chroot/
find /vyos/packages -name "*.deb" -exec cp -v {} /vyos/build/config/packages.chroot/ \;

# Modify the live-build configuration to handle our local repository
mkdir -p /vyos/build/config/includes.chroot/local-repo/
cp -rv /vyos/local-repo/* /vyos/build/config/includes.chroot/local-repo/

echo "Repository paths fixed."
