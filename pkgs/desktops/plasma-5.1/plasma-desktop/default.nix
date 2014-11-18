{ mkDerivation, utillinux }:

mkDerivation {
  patches = [
    ./plasma-desktop-hwclock.patch
    ./plasma-desktop-zoneinfo.patch
  ];

  preConfigure = ''
    substituteInPlace kcms/dateandtime/helper.cpp \
      --subst-var-by hwclock "${utillinux}/sbin/hwclock"
  '';
}
