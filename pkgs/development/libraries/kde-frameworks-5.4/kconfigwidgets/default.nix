{ mkDerivation }:

mkDerivation {
  patches = [ ./kconfigwidgets-helpclient-follow-symlinks.patch ];
}
