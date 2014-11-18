# DO NOT EDIT! This file is generated automatically.
{ }:
{
  baloo = {
    buildInputs = [ "KF5" "KF5Abc" "KF5Akonadi" "KF5AkonadiMime" "KF5AkonadiServer" "KF5CalendarCore" "KF5Mime" "KF5PimUtils" "Qt5" "Qt5Test" "Xapian" "kauth" "kcmutils" "kconfig" "kcrash" "kdelibs4support" "kfilemetadata" "kidletime" "kio" "solid" ];
    nativeBuildInputs = [ "cmake" "ki18n" ];
    propagatedBuildInputs = [ "Qt5Core" "Xapian" "kcoreaddons" "kfilemetadata" ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" ];
    propagatedUserEnvPkgs = [  ];
  };

  breeze = {
    buildInputs = [ "KDE4" "KF5" "PkgConfig" "Qt5" "XCB" "frameworkintegration" "kcompletion" "kconfig" "kconfigwidgets" "kcoreaddons" "kwin" "kwindowsystem" ];
    nativeBuildInputs = [ "cmake" "ki18n" ];
    propagatedBuildInputs = [  ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" ];
    propagatedUserEnvPkgs = [  ];
  };

  kde-cli-tools = {
    buildInputs = [ "KF5" "Qt5" "Qt5Test" "Qt5X11Extras" "X11" "kcmutils" "kconfig" "kdelibs4support" "kdesu" "kiconthemes" "kwindowsystem" ];
    nativeBuildInputs = [ "cmake" "ki18n" ];
    propagatedBuildInputs = [  ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" ];
    propagatedUserEnvPkgs = [  ];
  };

  kdeplasma-addons = {
    buildInputs = [ "GIO" "GLIB2" "GObject" "IBus" "KDE4" "KF5" "KdepimLibs" "Kexiv2" "Lancelot" "Lancelot-Datamodels" "Qt5" "SCIM" "SharedMimeInfo" "kcmutils" "kconfig" "kconfigwidgets" "kcoreaddons" "kdelibs4support" "kio" "krunner" "kservice" "kunitconversion" "plasma-framework" ];
    nativeBuildInputs = [ "cmake" "ki18n" ];
    propagatedBuildInputs = [  ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" ];
    propagatedUserEnvPkgs = [ "SharedMimeInfo" ];
  };

  kfilemetadata = {
    buildInputs = [ "EPub" "Exiv2" "FFmpeg" "KF5" "PopplerQt5" "QMobipocket" "Qt5" "Taglib" "karchive" ];
    nativeBuildInputs = [ "cmake" "ki18n" ];
    propagatedBuildInputs = [ "Qt5Core" ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" ];
    propagatedUserEnvPkgs = [  ];
  };

  khelpcenter = {
    buildInputs = [ "KF5" "Qt5" "kcmutils" "kconfig" "kdelibs4support" "khtml" "kinit" ];
    nativeBuildInputs = [ "cmake" "ki18n" ];
    propagatedBuildInputs = [  ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" ];
    propagatedUserEnvPkgs = [  ];
  };

  khotkeys = {
    buildInputs = [ "KF5" "Qt5" "X11" "kcmutils" "kdbusaddons" "kdelibs4support" "kglobalaccel" "kio" "kxmlgui" "plasma-framework" "plasma-workspace" ];
    nativeBuildInputs = [ "cmake" "ki18n" ];
    propagatedBuildInputs = [  ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" ];
    propagatedUserEnvPkgs = [  ];
  };

  kinfocenter = {
    buildInputs = [ "EGL" "KF5" "OpenGL" "OpenGLES" "PCIUTILS" "Qt5" "RAW1394" "X11" "kcmutils" "kcompletion" "kconfig" "kconfigwidgets" "kcoreaddons" "kdbusaddons" "kdelibs4support" "kiconthemes" "kio" "kservice" "kwayland" "kwidgetsaddons" "kxmlgui" "solid" ];
    nativeBuildInputs = [ "cmake" "kdoctools" "ki18n" ];
    propagatedBuildInputs = [  ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" ];
    propagatedUserEnvPkgs = [  ];
  };

  kio-extras = {
    buildInputs = [ "Exiv2" "JPEG" "KF5" "LibSSH" "OpenEXR" "Phonon4Qt5" "Qt5" "Qt5Test" "SLP" "Samba" "SharedMimeInfo" "karchive" "kconfig" "kconfigwidgets" "kcoreaddons" "kdbusaddons" "kdelibs4support" "kdnssd" "khtml" "kiconthemes" "kio" "solid" ];
    nativeBuildInputs = [ "MD5SUM_EXECUTABLE" "cmake" "kdoctools" "ki18n" ];
    propagatedBuildInputs = [  ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" ];
    propagatedUserEnvPkgs = [ "SharedMimeInfo" ];
  };

  kmenuedit = {
    buildInputs = [ "KF5" "Qt5" "kdbusaddons" "kdelibs4support" "khotkeys" "kiconthemes" "kio" "kxmlgui" "sonnet" ];
    nativeBuildInputs = [ "cmake" "ki18n" ];
    propagatedBuildInputs = [  ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" ];
    propagatedUserEnvPkgs = [  ];
  };

  ksysguard = {
    buildInputs = [ "KF5" "Qt5" "Sensors" "kconfig" "kcoreaddons" "kdelibs4support" "kiconthemes" "kitemviews" "knewstuff" "libksysguard" ];
    nativeBuildInputs = [ "cmake" "ki18n" ];
    propagatedBuildInputs = [  ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" ];
    propagatedUserEnvPkgs = [  ];
  };

  kwayland = {
    buildInputs = [ "Qt5" "Wayland" ];
    nativeBuildInputs = [ "WAYLAND_SCANNER_EXECUTABLE" "cmake" ];
    propagatedBuildInputs = [ "Qt5Gui" ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" ];
    propagatedUserEnvPkgs = [  ];
  };

  kwin = {
    buildInputs = [ "EGL" "KF5" "OpenGL" "OpenGLES" "Qt5" "Qt5Multimedia" "Qt5Test" "Wayland" "X11" "XCB" "XKB" "epoxy" "kactivities" "kcmutils" "kcompletion" "kconfig" "kconfigwidgets" "kcoreaddons" "kcrash" "kdeclarative" "kglobalaccel" "kinit" "kio" "knewstuff" "knotifications" "kservice" "kwayland" "kwidgetsaddons" "kwindowsystem" "kxmlgui" "plasma-framework" ];
    nativeBuildInputs = [ "cmake" "kdoctools" "ki18n" ];
    propagatedBuildInputs = [ "kconfig" "kservice" "kwindowsystem" ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" ];
    propagatedUserEnvPkgs = [  ];
  };

  kwrited = {
    buildInputs = [ "KF5" "Qt5" "kdbusaddons" "kdelibs4support" "kpty" ];
    nativeBuildInputs = [ "cmake" ];
    propagatedBuildInputs = [  ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" ];
    propagatedUserEnvPkgs = [  ];
  };

  libkscreen = {
    buildInputs = [ "Doxygen" "Qt5" "X11" "XCB" ];
    nativeBuildInputs = [ "cmake" ];
    propagatedBuildInputs = [ "Qt5Core" ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" ];
    propagatedUserEnvPkgs = [  ];
  };

  libksysguard = {
    buildInputs = [ "KF5" "Qt5" "Qt5X11Extras" "X11" "ZLIB" "kconfig" "kdelibs4support" "plasma-framework" ];
    nativeBuildInputs = [ "cmake" "ki18n" ];
    propagatedBuildInputs = [ "Qt5DBus" ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" ];
    propagatedUserEnvPkgs = [  ];
  };

  libmm-qt = {
    buildInputs = [ "ModemManager" "Qt4" "Qt5" "libmm-qt" ];
    nativeBuildInputs = [ "cmake" ];
    propagatedBuildInputs = [ "Qt5Core" ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" ];
    propagatedUserEnvPkgs = [  ];
  };

  libnm-qt = {
    buildInputs = [ "NetworkManager" "Qt4" "Qt5" "libnm-qt" ];
    nativeBuildInputs = [ "cmake" ];
    propagatedBuildInputs = [ "Qt5Core" ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" ];
    propagatedUserEnvPkgs = [  ];
  };

  milou = {
    buildInputs = [ "KF5" "KdepimLibs" "Qt5" "kdeclarative" "krunner" "plasma-framework" ];
    nativeBuildInputs = [ "cmake" "ki18n" ];
    propagatedBuildInputs = [  ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" ];
    propagatedUserEnvPkgs = [  ];
  };

  oxygen = {
    buildInputs = [ "KDE4" "KDE4Workspace" "KF5" "Qt5" "XCB" "frameworkintegration" "kcompletion" "kconfig" "kguiaddons" "kservice" "kwidgetsaddons" "kwin" "kwindowsystem" ];
    nativeBuildInputs = [ "cmake" "ki18n" ];
    propagatedBuildInputs = [  ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" ];
    propagatedUserEnvPkgs = [  ];
  };

  oxygen-fonts = {
    buildInputs = [  ];
    nativeBuildInputs = [ "FONTFORGE_EXECUTABLE" "cmake" ];
    propagatedBuildInputs = [  ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" ];
    propagatedUserEnvPkgs = [  ];
  };

  plasma-desktop = {
    buildInputs = [ "Fontconfig" "Freetype" "GLIB2" "KDE4" "KF5" "OpenGL" "OpenGLES" "PackageKitQt5" "Phonon4Qt5" "PulseAudio" "Qt4" "Qt5" "Strigi" "USB" "X11" "XCB" "attica" "kactivities" "kauth" "kcmutils" "kdelibs4support" "kemoticons" "kitemmodels" "knewstuff" "knotifyconfig" "krunner" "kwallet" "kwin" "plasma-framework" "plasma-workspace" ];
    nativeBuildInputs = [ "cmake" "kdoctools" "ki18n" ];
    propagatedBuildInputs = [  ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" ];
    propagatedUserEnvPkgs = [  ];
  };

  plasma-nm = {
    buildInputs = [ "KF5" "MobileBroadbandProviderInfo" "ModemManager" "NetworkManager" "OpenConnect" "OpenSSL" "Qt5" "kcompletion" "kconfigwidgets" "kcoreaddons" "kdbusaddons" "kdeclarative" "kdelibs4support" "kiconthemes" "kinit" "kio" "kitemviews" "knotifications" "kservice" "kwallet" "kwidgetsaddons" "kwindowsystem" "kxmlgui" "libmm-qt" "libnm-qt" "plasma-framework" "solid" ];
    nativeBuildInputs = [ "cmake" "ki18n" ];
    propagatedBuildInputs = [  ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" ];
    propagatedUserEnvPkgs = [  ];
  };

  plasma-workspace = {
    buildInputs = [ "KF5" "KF5NO_MODULE" "Phonon4Qt5" "Prison" "Qalculate" "Qt5" "Qt5DBus" "Qt5Qml" "Qt5Quick" "Qt5Script" "Qt5Test" "X11" "XCB" "ZLIB" "baloo" "dbusmenu-qt5" "kactivities" "kcmutils" "kconfig" "kcoreaddons" "kcrash" "kdbusaddons" "kdeclarative" "kdelibs4support" "kdesu" "kdewebkit" "kidletime" "kio" "kjsembed" "knewstuff" "knotifyconfig" "krunner" "ktexteditor" "ktextwidgets" "kwallet" "kwin" "libgps" "libkscreen" "libksysguard" "plasma-framework" "solid" ];
    nativeBuildInputs = [ "cmake" "kdoctools" "ki18n" ];
    propagatedBuildInputs = [ "kio" "libksysguard" ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" ];
    propagatedUserEnvPkgs = [  ];
  };

  plasma-workspace-wallpapers = {
    buildInputs = [  ];
    nativeBuildInputs = [ "cmake" ];
    propagatedBuildInputs = [  ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" ];
    propagatedUserEnvPkgs = [  ];
  };

  powerdevil = {
    buildInputs = [ "KF5" "Qt5" "UDev" "X11" "XCB" "kauth" "kconfig" "kdelibs4support" "kglobalaccel" "kidletime" "kio" "knotifyconfig" "plasma-workspace" "solid" ];
    nativeBuildInputs = [ "cmake" "ki18n" ];
    propagatedBuildInputs = [  ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" ];
    propagatedUserEnvPkgs = [  ];
  };

  systemsettings = {
    buildInputs = [ "KF5" "Qt5" "kcmutils" "kconfig" "kdbusaddons" "kdelibs4support" "khtml" "kiconthemes" "kio" "kitemviews" "kservice" "kwindowsystem" "kxmlgui" ];
    nativeBuildInputs = [ "cmake" "ki18n" ];
    propagatedBuildInputs = [  ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" ];
    propagatedUserEnvPkgs = [  ];
  };

}
