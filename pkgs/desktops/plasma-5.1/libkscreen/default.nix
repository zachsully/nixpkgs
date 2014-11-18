{ mkDerivation }:

mkDerivation {
  patches = [ ./libkscreen-backend-path.patch ];
}
