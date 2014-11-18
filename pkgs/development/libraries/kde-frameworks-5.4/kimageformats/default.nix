{ mkDerivation, ilmbase }:

mkDerivation {
  NIX_CFLAGS_COMPILE = "-I${ilmbase}/include/OpenEXR";
}
