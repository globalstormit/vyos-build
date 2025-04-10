#!/bin/bash
# https://docs.vyos.io/en/latest/contributing/build-vyos.html#build

ARCH=amd64
EMAIL="luke@gsit.ca"
VERSION=sagitta
BUILDTYPE=development

git clean -fd
git checkout $VERSION
sudo docker build -t vyos/vyos-build:$VERSION docker

sudo docker run --rm -it --privileged -v $(pwd):/vyos -w /vyos vyos/vyos-build:$VERSION bash -c "sudo make clean && sudo ./build-vyos-image --architecture $ARCH --build-by '$EMAIL' --build-type $BUILDTYPE generic"
