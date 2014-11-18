{ mkDerivation }:

mkDerivation {
  patches = [ ./kservice-no-canonicalpath.patch ];
}
