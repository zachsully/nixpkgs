{ mkDerivation }:

mkDerivation {
  postInstall = ''
    # We use a custom startkde script
    rm $out/bin/startkde
  '';
}
