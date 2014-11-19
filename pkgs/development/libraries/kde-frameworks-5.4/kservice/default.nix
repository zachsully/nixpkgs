{ mkDerivation }:

mkDerivation {
  patches = [
    ./kservice-kbuildsycoca-follow-symlinks.patch
    ./kservice-kbuildsycoca-no-canonicalize.patch
  ];
}
