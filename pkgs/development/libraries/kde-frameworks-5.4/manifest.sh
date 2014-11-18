#!/bin/sh

# The extra slash at the end of the URL is necessary to stop wget
# from recursing over the whole server! (No, it's not a bug.)
../../../build-support/autonix/manifest.sh \
    http://download.kde.org/stable/frameworks/5.4/ \
    -A '*.tar.xz'
