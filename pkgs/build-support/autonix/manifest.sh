#!/bin/sh

mkdir tmp; cd tmp

wget -nH -r -c --no-parent $*

cat >../manifest.nix <<EOF
# This file is generated automatically. DO NOT EDIT!
{ mirror }:
[
EOF

workdir=$(pwd)

find . | while read path; do
    if [[ -f "${path}" ]]; then
        url="${path:2}"
        # Sanitize file name
        name=$(basename "${path}" | tr '@' '_')
        dirname=$(dirname "${path}")
        mv "${workdir}/${path}" "${workdir}/${dirname}/${name}"
        # Prefetch and hash source file
        sha256=$(nix-prefetch-url "file://${workdir}/${dirname}/${name}")
        store=$(nix-store --print-fixed-path sha256 "$sha256" "$name")
        cat >>../manifest.nix <<EOF
  {
    url = "\${mirror}/${url}";
    sha256 = "${sha256}";
    name = "${name}";
    store = "${store}";
  }
EOF
    fi
done

echo "]" >>../manifest.nix

cd ..
