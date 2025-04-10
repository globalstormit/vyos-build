#!/bin/bash
# https://docs.vyos.io/en/latest/contributing/build-vyos.html#build

# Set sudo timeout to unlimited (until reboot)
echo "Setting sudo timeout to unlimited for build process..."
sudo sh -c 'echo "Defaults timestamp_timeout=0" > /etc/sudoers.d/vyos-build-extend-timeout'

source ./.env

# Derive VERSION from current git branch
VERSION=$(git symbolic-ref --short HEAD)
echo "Detected branch: $VERSION"

git clean -fd
# No need to checkout as we're already on the correct branch
# git checkout $VERSION

# Check if Docker image already exists
if ! sudo docker image inspect vyos/vyos-build:$VERSION &>/dev/null; then
    echo "Building Docker container for VyOS $VERSION..."
    sudo docker build -t vyos/vyos-build:$VERSION docker
else
    echo "Using existing Docker container for VyOS $VERSION"
fi

# Create directory for local packages
mkdir -p ./local-packages

# Run container to build kernel and drivers
echo "Building kernel and drivers..."
sudo docker run --rm --privileged -v $(pwd):/vyos -w /vyos vyos/vyos-build:$VERSION bash -c "
    cd /vyos/packages/linux-kernel
    ./build-kernel.sh
    # Build the Intel drivers
    ./build-intel-ixgbe.sh
    ./build-intel-ixgbevf.sh
    ./build-intel-qat.sh
    ./build-linux-firmware.sh
    # Move all built packages to local-packages directory
    mv *.deb /vyos/local-packages/ 2>/dev/null || true
"

# Create a local apt repository
echo "Creating local package repository..."
sudo docker run --rm --privileged -v $(pwd):/vyos -w /vyos vyos/vyos-build:$VERSION bash -c "
    cd /vyos/local-packages
    apt-get update
    apt-get install -y dpkg-dev
    dpkg-scanpackages . > Packages
    gzip -k Packages
"

# Now run the build with the local repository
sudo docker compose up

# Clean up the temporary sudoers file
sudo rm -f /etc/sudoers.d/vyos-build-extend-timeout
