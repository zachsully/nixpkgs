{ mkDerivation }:

mkDerivation {
  patches = [ ./kinit-libpath.patch ];
}
