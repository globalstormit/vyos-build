#!/bin/bash

# execute build.sh and log output to build.log

sudo ./build.sh 2>&1 | tee ./build.log