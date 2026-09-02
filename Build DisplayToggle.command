#!/bin/bash
# Double-click this file in Finder to build and install DisplayToggle.
# It only calls build.sh, so there is one copy of the build steps.
cd "$(dirname "$0")"
./build.sh "$@"
