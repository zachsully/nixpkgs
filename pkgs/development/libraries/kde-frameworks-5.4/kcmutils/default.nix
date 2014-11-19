{ mkDerivation }:

mkDerivation {
  patches = [ ./kcmutils-pluginselector-follow-symlinks.patch ];
}
