{ mkDerivation }:

mkDerivation {
  patches = [ ./kauth-policy-install.patch ];
}
