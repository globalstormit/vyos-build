#!/bin/bash
# https://docs.vyos.io/en/latest/contributing/build-vyos.html#build

# Set sudo timeout to 4 hours (14400 seconds)
echo "Setting sudo timeout to 4 hours for build process..."
sudo sh -c 'echo "Defaults timestamp_timeout=14400" > /etc/sudoers.d/vyos-build-extend-timeout'
sudo docker compose down

source ./.env

# Derive VERSION from current git branch
# VERSION=$(git symbolic-ref --short HEAD)
# echo "Detected branch: $VERSION"

git clean -fd

# Check if Docker image already exists
if ! sudo docker image inspect vyos/vyos-build:$VERSION &>/dev/null; then
    echo "Building Docker container for VyOS $VERSION..."
    sudo docker build -t vyos/vyos-build:$VERSION docker
else
    echo "Using existing Docker container for VyOS $VERSION"
fi

# Create local repository using dedicated script
echo "Creating local package repository..."
chmod +x ./scripts/create-local-repo.sh
sudo docker run --rm --privileged -v $(pwd):/vyos -w /vyos vyos/vyos-build:$VERSION bash -c "/vyos/scripts/create-local-repo.sh"

# Build kernel and drivers using dedicated script
echo "Building kernel and drivers..."
chmod +x ./scripts/build-kernel-drivers.sh
sudo docker run --rm --privileged -v $(pwd):/vyos -w /vyos vyos/vyos-build:$VERSION bash -c "/vyos/scripts/build-kernel-drivers.sh"



# Now run the build with the local repository
sudo docker compose up

# Clean up the temporary sudoers file
sudo rm -f /etc/sudoers.d/vyos-build-extend-timeout
