{ autonix, haskellPackages, kde4, kf54, pkgs, qt4, stdenv
, debug ? false }:

with stdenv.lib; with autonix;

let

  manifestOrig = import ./manifest.nix { mirror = "mirror://kde"; };
  manifestDropKWayland = filterAttrs (n: v: n != "kwayland");
  manifest = manifestDropKWayland (manifestWithNames manifestOrig);

  dependenciesOrig = import ./dependencies.nix {};
  dependenciesFilterKWayland = mapAttrs (n: v: v // {
    buildInputs = remove "kwayland" v.buildInputs;
    nativeBuildInputs = remove "kwayland" v.nativeBuildInputs;
    propagatedBuildInputs = remove "kwayland" v.propagatedBuildInputs;
    propagatedNativeBuildInputs =
      remove "kwayland" v.propagatedNativeBuildInputs;
    propagatedUserEnvPkgs =
      remove "kwayland" v.propagatedUserEnvPkgs;
  });
  dependencies = (dependenciesFilterKWayland dependenciesOrig) // {
    # Automatic dependencies for breeze interferes with building Qt4 and Qt5
    # styles separately. This won't be a problem if upstream ever supports
    # building both styles in the same source tree.
    breeze = emptyDeps;
  };

  kf5 = kf54.override { inherit debug; };
  inherit (kf5) qt5;

  extraInputs = kf5 // { inherit kde4; };

  extraOutputs = {
    inherit kf5 qt5 qt4;
    poppler_qt5 = (pkgs.poppler.override { inherit qt5; }).poppler_qt5;
    breeze_qt4 = plasma5.dev.callAutonixPackage ./. "breeze" {
      withQt5 = false;
    };
    startkde = plasma5.dev.callPackage ./startkde {};
  };

  names = with pkgs; with extraOutputs; kf5.dev.names // {
    dbusmenu-qt5 = libdbusmenu_qt5;
    inherit epoxy;
    EPub = ebook_tools;
    Exiv2 = exiv2;
    FFmpeg = ffmpeg;
    Fontconfig = fontconfig;
    FONTFORGE_EXECUTABLE = fontforge;
    Freetype = freetype;
    GIO = glib;
    GLIB2 = glib;
    IBus = ibus;
    MobileBroadbandProviderInfo = mobile_broadband_provider_info;
    ModemManager = modemmanager;
    NetworkManager = networkmanager;
    OpenConnect = openconnect;
    PCIUTILS = pciutils;
    PopplerQt5 = poppler_qt5;
    Prison = kf5.prison;
    PulseAudio = pulseaudio;
    RAW1394 = libraw1394;
    Sensors = lm_sensors;
    Taglib = taglib;
    USB = libusb;
    Xapian = xapian;
  };

  overrides = {
    frameworkintegration = {
      buildInputs = [ plasma5.oxygen-fonts ];
    };
    kwin = {
      buildInputs = with pkgs.xlibs; [ libICE libSM libXcursor ];
    };
    libkscreen = {
      buildInputs = with pkgs.xlibs; [ libXrandr ];
    };
    plasma-desktop = {
      buildInputs = with pkgs.xlibs; [ pkgs.libcanberra libxkbfile libXcursor ];
    };
    plasma-workspace = {
      buildInputs = with pkgs.xlibs; [ libSM libXcursor pkgs.pam ];
    };
    powerdevil = {
      buildInputs = with pkgs.xlibs; [ libXrandr ];
    };
  };

  plasma5 = autonix.generateCollection ./. {
    inherit dependencies extraInputs extraOutputs manifest names overrides;
    deriver = kf5.dev.mkDerivation;
  };

in plasma5
