{ stdenvAdapters, stdenv, debug, autonix, cmake, pkgconfig, qt5 }:

let stdenvOrig = stdenv; in
let
  stdenv =
    if debug
      then stdenvAdapters.keepDebugInfo stdenvOrig
    else stdenvOrig;
in

args:
attrs:

with stdenv.lib;
with autonix;
let
  isNotECM = !(hasPrefix "extra-cmake-modules" (head attrs).name);
in
stdenv.mkDerivation (autonix.mergeAttrsByFuncDefaultsClean
  (attrs ++ [
    {
      setupHook = ./setup-hook.sh;
      enableParallelBuilding = true;
      cmakeFlags =
        [ "-DBUILD_TESTING=OFF"
          "-DKDE_DEFAULT_HOME=.kde5"
          "-DKDE4_DEFAULT_HOME=.kde"
        ]
        ++ optional debug "-DCMAKE_BUILD_TYPE=Debug";
      meta = {
        license = with stdenv.lib.licenses; [
          lgpl21Plus lgpl3Plus bsd2 mit gpl2Plus gpl3Plus fdl12
        ];
        platforms = stdenv.lib.platforms.linux;
        maintainers = with stdenv.lib.maintainers; [ ttuegel ];
        homepage = "http://www.kde.org";
      };
    }
    args
  ]))
