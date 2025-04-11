#!/bin/bash
# Script to build Linux kernel and Intel drivers for VyOS
# This script should be run inside the VyOS build container

set -e

cd /vyos/packages/linux-kernel

# Function to check if a package already exists in the local repo
check_package_exists() {
    local pattern=$1
    local count=$(ls -1 /vyos/local-packages/${pattern} 2>/dev/null | wc -l)
    return $((count == 0))
}

# Get kernel version from data/defaults.toml
KERNEL_VER=$(grep kernel_version /vyos/data/defaults.toml | awk -F\" '{print $2}')
echo "Using kernel version: ${KERNEL_VER}"

# Clone or update kernel repository
if [ ! -d linux ]; then 
    echo 'Cloning Linux kernel repository...'
    # Clone the specific version
    git clone --depth=1 --branch=v${KERNEL_VER} https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git
else
    echo "Linux kernel directory already exists. Checking repository..."
    # Verify it's a git repository
    if [ -d linux/.git ]; then
        echo "Updating existing kernel repository..."
        cd linux
        git fetch --depth=1
        git reset --hard origin/v${KERNEL_VER}
        cd ..
    else
        echo "Warning: linux directory exists but is not a git repository."
        echo "Using existing directory without updating."
    fi
fi



# Build the kernel if not already built
if check_package_exists "linux-image-*.deb"; then
    echo "Building Linux kernel..."
    ./build-kernel.sh
    mv *.deb /vyos/local-packages/ 2>/dev/null || true
else
    echo "Linux kernel packages already exist. Skipping build."
fi

# Build the Intel ixgbe driver if not already built
if check_package_exists "vyos-intel-ixgbe_*.deb"; then
    echo "Building Intel ixgbe driver..."
    ./build-intel-ixgbe.sh
    mv *.deb /vyos/local-packages/ 2>/dev/null || true
else
    echo "Intel ixgbe driver package already exists. Skipping build."
fi

# Build the Intel ixgbevf driver if not already built
if check_package_exists "vyos-intel-ixgbevf_*.deb"; then
    echo "Building Intel ixgbevf driver..."
    ./build-intel-ixgbevf.sh
    mv *.deb /vyos/local-packages/ 2>/dev/null || true
else
    echo "Intel ixgbevf driver package already exists. Skipping build."
fi

# Build the Intel QAT driver if not already built
if check_package_exists "vyos-intel-qat_*.deb"; then
    echo "Building Intel QAT driver..."
    ./build-intel-qat.sh
    mv *.deb /vyos/local-packages/ 2>/dev/null || true
else
    echo "Intel QAT driver package already exists. Skipping build."
fi

# Build the Linux firmware package if not already built
if check_package_exists "vyos-linux-firmware_*.deb"; then
    echo "Building Linux firmware package..."
    ./build-linux-firmware.sh
    mv *.deb /vyos/local-packages/ 2>/dev/null || true
else
    echo "Linux firmware package already exists. Skipping build."
fi

# Ensure the local-packages directory exists
echo "Ensuring local repository directory exists..."
mkdir -p /vyos/local-packages

# Clean up any temporary files
echo "Cleaning up temporary files..."
rm -f vyos-intel-ixgbe.postinst 2>/dev/null || true
rm -f vyos-intel-ixgbevf.postinst 2>/dev/null || true
rm -f vyos-intel-qat.postinst 2>/dev/null || true

echo "Kernel and drivers built successfully!"
