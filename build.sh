#!/bin/bash
# https://docs.vyos.io/en/latest/contributing/build-vyos.html#build

# Set sudo timeout to 4 hours (14400 seconds)
echo "Setting sudo timeout to 4 hours for build process..."
sudo sh -c 'echo "Defaults timestamp_timeout=14400" > /etc/sudoers.d/vyos-build-extend-timeout'
sudo docker compose down

source ./.env

git clean -fd

# Check if Docker image already exists
if ! sudo docker image inspect vyos/vyos-build:$VERSION &>/dev/null; then
    echo "Building Docker container for VyOS $VERSION..."
    sudo docker build -t vyos/vyos-build:$VERSION docker
else
    echo "Using existing Docker container for VyOS $VERSION"
fi

# Run all steps in the same container session to avoid repository issues
sudo docker run --rm --privileged -v $(pwd):/vyos -w /vyos \
    -e ARCH=$ARCH -e EMAIL="$EMAIL" -e BUILD_TYPE=$BUILD_TYPE -e BUILD_FLAVOR=$BUILD_FLAVOR -e VERSION=$VERSION \
    vyos/vyos-build:$VERSION bash -c "
        cd /vyos;
        sudo make clean;
        sudo ./build-vyos-image --architecture $ARCH --build-by '$EMAIL' --build-type $BUILD_TYPE $BUILD_FLAVOR;
    "

# Clean up the temporary sudoers file
sudo rm -f /etc/sudoers.d/vyos-build-extend-timeout
