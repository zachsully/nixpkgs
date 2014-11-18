#!/bin/sh

manifestXML=$(nix-build ../../../.. -A kf54.dev.manifest)

autonixDepsKf5=""
if [[ -z $1 ]]; then
    autonixDepsKF5=$(nix-build ../../../.. -A haskellPackages.autonixDepsKf5)/bin
else
    autonixDepsKF5="$1/dist/build/kf5-deps"
fi

exec ${autonixDepsKF5}/kf5-deps "${manifestXML}"
