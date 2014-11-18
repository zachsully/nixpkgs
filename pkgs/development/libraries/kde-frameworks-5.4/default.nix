{ autonix, haskellPackages, pkgs, qt5, stdenv
, debug ? false }:

with stdenv.lib; with autonix;

let

  inherit (kf5.dev) callPackage;

  kf-package = callPackage ./kf-package { inherit debug; };

  manifest = manifestWithNames (import ./manifest.nix { mirror = "mirror://kde"; });

  dependencies = import ./dependencies.nix {};

  extraInputs = {
    inherit kf-package;
  };

  extraOutputs = {
    inherit qt5;
    libdbusmenu_qt5 = pkgs.libdbusmenu_qt5.override { inherit qt5; };
    phonon_qt5 = pkgs.phonon_qt5.override { inherit qt5; };
    polkit_qt5 = pkgs.polkit_qt5.override { inherit qt5; };
    prison = callPackage ../prison/qt5.nix {};
  };

  names = with pkgs; with extraOutputs; {
    Avahi = avahi;
    BISON = bison;
    Boost = boost;
    BZip2 = bzip2;
    inherit cmake;
    dbusmenu-qt5 = libdbusmenu_qt5;
    Eigen2 = eigen2;
    ENCHANT = enchant;
    FLEX = flex;
    GIF = giflib;
    GObject = glib;
    Grantlee = grantlee;
    GStreamer = gstreamer;
    Jasper = jasper;
    JPEG = libjpeg;
    LibGcrypt = libgcrypt;
    LibLZMA = lzma;
    OpenEXR = openexr;
    OpenSSL = openssl;
    Perl = perl;
    Phonon4Qt5 = phonon_qt5;
    inherit pkgconfig;
    PNG = libpng;
    PythonInterp = python;
    QCA2 = qca2;
    QImageBlitz = qimageblitz;
    Qt5 = qt5;
    Qt5Core = qt5;
    Qt5DBus = qt5;
    Qt5Gui = qt5;
    SharedMimeInfo = shared_mime_info;
    Sqlite = sqlite;
    Strigi = strigi;
    XCB = xlibs.xcbproto;
    ZLIB = zlib;
  };

  overrides = with pkgs; with kf5; {

    kauth = {
      buildInputs = [ polkit_qt5 ];
    };

    ki18n = {
      propagatedNativeBuildInputs = [ gettext python ];
    };

    kservice = {
      buildInputs = [ kwindowsystem ];
    };

  };

  kf5 = autonix.generateCollection ./. {
    inherit manifest dependencies extraInputs extraOutputs names overrides;
    deriver = kf-package;
  };
in kf5
