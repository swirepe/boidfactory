#!/usr/bin/env bash
find runs -type d -depth -exec ./build-link-viewer.sh {} \;
