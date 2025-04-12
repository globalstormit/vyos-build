#!/bin/bash
# Script to build Linux kernel and Intel drivers for VyOS
# This script should be run inside the VyOS build container

set -e


build_package() {
    local script=$1
    local pattern=$2
    local force=${3:-0}
    
    package_exists=$(ls -1 ${pattern} 2>/dev/null | wc -l)
    echo "Checking for ${pattern}"
    
    if [ $package_exists -eq 0 ] || [ $force -eq 1 ]; then
        echo "Building ${script}..."
        ./"$script"
        if [ $? -ne 0 ]; then
            echo "Error building ${script}!"
            exit 1
        fi
        echo "Successfully built ${script}"
    else
        echo "Package already exists. Skipping build."
    fi
}

clone_kernel_repo() {
    NAME=$1 # linux-firmware - label and directory name
    URL=$2  # https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git  - download url for the repo
    if [ ! -d $NAME ]; then 
        echo "Cloning $NAME repository..."
        # Clone the firmware repository
        git clone --depth=1 $URL
    else
        echo "$NAME repository already exists. Checking repository..."
        # Verify it's a git repository
        if [ -d $NAME/.git ]; then
            echo "Using existing $NAME repository..."
            cd $NAME
            echo "Current version: $(git describe --always 2>/dev/null || echo 'unknown')"
            cd ..
        else
            echo "Warning: $NAME directory exists but is not a git repository."
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

# Clone repositories
clone_kernel_repo "linux" "https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git"
clone_kernel_repo "linux-firmware" "https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git"

# Build packages in the correct order
# Always build the kernel first - force=1 ensures it builds even if package exists
# This is needed to create the correct directory structure expected by other scripts
echo "Building kernel package..."
build_package "build-kernel.sh" "linux-image-*.deb"

# Now build the driver packages
echo "Building driver packages..."
build_package "build-intel-ixgbe.sh" "vyos-intel-ixgbe*.deb"
build_package "build-intel-ixgbevf.sh" "vyos-intel-ixgbevf*.deb"
build_package "build-intel-qat.sh" "vyos-intel-qat*.deb"
build_package "build-linux-firmware.sh" "vyos-linux-firmware*.deb"
# build_package "build-openvpn-dco.sh" "vyos-openvpn-dco*.deb"


# Simplified symlink creation - process all packages at once
echo "Creating symlinks and copying packages..."

# Ensure local repo pool directory exists
mkdir -p /vyos/local-repo/pool/main

# Process kernel packages differently (they need symlinks with linux-kernel/ prefix)
for deb in linux-*.deb; do
    if [ -f "$deb" ]; then
        echo "  Processing kernel package: $deb"
        # Create symlink in parent directory with prefix
        ln -sf linux-kernel/$deb ..
        # Copy to local repo pool directory
        cp $deb /vyos/local-repo/pool/main/
    fi
done

# Process all non-kernel packages (copy to both locations)
for deb in vyos-*.deb accel-ppp*.deb; do
    if [ -f "$deb" ]; then
        echo "  Processing package: $deb"
        # Create symlink in parent directory with prefix
        ln -sf linux-kernel/$deb ..
        # Copy to local repo pool directory
        cp $deb /vyos/local-repo/pool/main/
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
echo "Packages in local repository pool:"
ls -la /vyos/local-repo/pool/main/*.deb 2>/dev/null || echo "No packages found"
echo "==============================================="

echo "Kernel and drivers built successfully!"
