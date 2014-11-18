{ mkDerivation }:

mkDerivation {
  patches = [ ./plasma-framework-external-paths.patch ];
}
