{ stdenv, fetchgit, cmake, extra-cmake-modules, qrencode, qt5, libdmtx }:

stdenv.mkDerivation {
  name = "prison-git-3ec65411-1.2";

  src = fetchgit {
    url = "git://anongit.kde.org/prison";
    rev = "3ec654110e501c7bcf30c2986b550521bd347ce6";
    sha256 = "32476f53f63cbecb9f582632e7b5867ad83d54c0cd99d35cbd3db0b4ad7bc0a8";
  };

  buildInputs = [ qt5 qrencode libdmtx ];

  cmakeFlags = [ "-DQT5_BUILD=ON" ];

  nativeBuildInputs = [ cmake extra-cmake-modules ];

  meta = {
    description = "Qt5 library for QR-codes";
    maintainers = [ stdenv.lib.maintainers.ttuegel ];
    inherit (qt5.meta) platforms;
  };
}
