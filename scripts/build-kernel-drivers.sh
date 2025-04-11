#!/bin/bash
# Script to build Linux kernel and Intel drivers for VyOS
# This script should be run inside the VyOS build container

set -e


build_package() {
    local script=$1
    local pattern=$2
    package_exists=$(ls -1 ${pattern} 2>/dev/null | wc -l)
    echo "$pattern"
    if [ $package_exists -eq 0 ]; then
        echo "Building..."
        ./"$script"
    else
        echo "Already exists. skipping build"
    fi
}

clone_linux_repo() {
    if [ ! -d linux ]; then 
        echo 'Cloning Linux kernel repository...'
        # Clone the specific version
        git clone --depth=1 --branch=v${KERNEL_VER} https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git
    else
        echo "Linux kernel directory already exists. Checking repository..."
        # Verify it's a git repository
        if [ -d linux/.git ]; then
            echo "Using existing kernel repository..."
            cd linux
            # Check the current version to verify
            echo "Current kernel version: $(git describe --tags 2>/dev/null || echo 'unknown')"
            cd ..
        else
            echo "Warning: linux directory exists but is not a git repository."
            echo "Using existing directory without updating."
        fi
    fi
}


cd /vyos/packages/linux-kernel

# Determine architecture and version from build configuration
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

echo "Building for architecture: $ARCH"
echo "VyOS version: $VERSION"

# Get kernel version from data/defaults.toml
KERNEL_VER=$(grep kernel_version /vyos/data/defaults.toml | awk -F\" '{print $2}')
echo "Using kernel version: ${KERNEL_VER}"

# Clone or update kernel repository
clone_linux_repo

# Build packages
build_package "build-kernel.sh" "linux-image-*.deb"
build_package "build-intel-ixgbe.sh" "vyos-intel-ixgbe*.deb"
build_package "build-intel-ixgbevf.sh" "vyos-intel-ixgbevf*.deb"
build_package "build-intel-qat.sh" "vyos-intel-qat*.deb"
build_package "build-linux-firmware.sh" "vyos-linux-firmware*.deb"
build_package "build-openvpn-dco.sh" "vyos-openvpn-dco*.deb"


# Simplified symlink creation - process all packages at once
echo "Creating symlinks and copying packages..."

# Process kernel packages differently (they need symlinks with linux-kernel/ prefix)
for deb in linux-*.deb; do
    if [ -f "$deb" ]; then
        echo "  Processing kernel package: $deb"
        # Create symlink in parent directory with prefix
        ln -sf linux-kernel/$deb ..
        # Copy to local repo
        cp $deb /vyos/local-repo/
    fi
done

# Process all non-kernel packages (copy to both locations)
for deb in vyos-*.deb accel-ppp*.deb; do
    if [ -f "$deb" ]; then
        echo "  Processing package: $deb"
        # Create symlink in parent directory with prefix
        ln -sf linux-kernel/$deb ..
        # Copy to local repo
        cp $deb /vyos/local-repo/
    fi
done

# Clean up any temporary files
echo "Cleaning up temporary files..."
rm -f vyos-intel-*.postinst 2>/dev/null || true

# List what we've built and symlinked
echo "==============================================="
echo "Build summary:"
echo "==============================================="
echo "Built packages in /vyos/packages/linux-kernel/:"
ls -la *.deb 2>/dev/null || echo "No packages found"
echo "----------------------------------------------"
echo "Packages in parent directory (expected by build system):"
ls -la /vyos/packages/*.deb 2>/dev/null || echo "No packages found"
echo "----------------------------------------------"
echo "Packages in local repository:"
ls -la /vyos/local-repo/*.deb 2>/dev/null || echo "No packages found"
echo "==============================================="

echo "Kernel and drivers built successfully!"
