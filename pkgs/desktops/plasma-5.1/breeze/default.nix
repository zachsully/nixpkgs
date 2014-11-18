{ mkDerivation, stdenv
, kde4, qt4, qt5, withQt5 ? true
, cmake, extra-cmake-modules, frameworkintegration, kcompletion, kconfig
, kconfigwidgets, kcoreaddons, ki18n, kwin, kwindowsystem, pkgconfig, xlibs }:

with stdenv.lib;

mkDerivation {
  buildInputs =
    [ xlibs.xproto ]
    ++ (if withQt5
      then [
        frameworkintegration kcompletion kconfig kconfigwidgets kcoreaddons
        kwin kwindowsystem qt5
      ]
      else [ kde4.kdelibs qt4 ]);

  nativeBuildInputs = [ cmake pkgconfig ]
    ++ optionals withQt5 [ extra-cmake-modules ki18n ];

  cmakeFlags = optional (!withQt5) "-DUSE_KDE4=ON";
}
