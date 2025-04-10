#!/bin/bash
# Script to build Linux kernel and Intel drivers for VyOS
# This script should be run inside the VyOS build container

set -e

cd /vyos/packages/linux-kernel

# Clone kernel if it doesn't exist 
if [ ! -d linux ]; then 
    echo 'Cloning Linux kernel repository...'
    # Get kernel version from data/defaults.toml
    KERNEL_VER=$(grep kernel_version /vyos/data/defaults.toml | awk -F\" '{print $2}')
    echo "Using kernel version: ${KERNEL_VER}"
    
    # Clone the specific version
    git clone --depth=1 --branch=v${KERNEL_VER} https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git
fi

# Build the kernel 
echo "Building Linux kernel..."
./build-kernel.sh

# Build the Intel drivers
echo "Building Intel ixgbe driver..."
./build-intel-ixgbe.sh

echo "Building Intel ixgbevf driver..."
./build-intel-ixgbevf.sh

echo "Building Intel QAT driver..."
./build-intel-qat.sh

echo "Building Linux firmware package..."
./build-linux-firmware.sh

# Move all built packages to local-packages directory
echo "Moving packages to local repository..."
mkdir -p /vyos/local-packages
mv *.deb /vyos/local-packages/ 2>/dev/null || true

echo "Kernel and drivers built successfully!"
