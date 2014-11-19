{ mkDerivation }:

mkDerivation {
  patches = [ ./kwin-import-plugin-follow-symlinks.patch ];
}
