# DO NOT EDIT! This file is generated automatically.
{ }:
{
  attica = {
    buildInputs = [ "Qt5" "Qt5Widgets" ];
    nativeBuildInputs = [ "cmake" ];
    propagatedBuildInputs = [ "Qt5Core" ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" ];
    propagatedUserEnvPkgs = [  ];
  };

  extra-cmake-modules = {
    buildInputs = [ "AGG" "Blitz" "BlueZ" "ENCHANT" "Eigen2" "FFmpeg" "Flac" "Flex" "GObject" "GStreamer" "LCMS" "LibArt" "OpenEXR" "PCRE" "QCA2" "QImageBlitz" "Qt5Core" "Qt5LinguistTools" "Sqlite" "Strigi" "USB" "Xine" "Xmms" ];
    nativeBuildInputs = [ "LibXslt" "QCOLLECTIONGENERATOR_EXECUTABLE" "SPHINX_EXECUTABLE" "cmake" ];
    propagatedBuildInputs = [  ];
    propagatedNativeBuildInputs = [  ];
    propagatedUserEnvPkgs = [  ];
  };

  frameworkintegration = {
    buildInputs = [ "OxygenFont" "Qt5" "Qt5Test" "XCB" "kconfig" "kconfigwidgets" "kiconthemes" "kio" "knotifications" "kwidgetsaddons" ];
    nativeBuildInputs = [ "cmake" "ki18n" ];
    propagatedBuildInputs = [ "kconfigwidgets" "kiconthemes" ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" ];
    propagatedUserEnvPkgs = [  ];
  };

  kactivities = {
    buildInputs = [ "Boost" "KF5" "Qt5" "kcmutils" "kconfig" "kcoreaddons" "kdbusaddons" "kdeclarative" "kglobalaccel" "kio" "kservice" "kwindowsystem" "kxmlgui" ];
    nativeBuildInputs = [ "cmake" "ki18n" ];
    propagatedBuildInputs = [ "Qt5Core" ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" ];
    propagatedUserEnvPkgs = [  ];
  };

  kapidox = {
    buildInputs = [  ];
    nativeBuildInputs = [ "PythonInterp" "cmake" ];
    propagatedBuildInputs = [  ];
    propagatedNativeBuildInputs = [  ];
    propagatedUserEnvPkgs = [  ];
  };

  karchive = {
    buildInputs = [ "BZip2" "LibLZMA" "Qt5Core" "Qt5Test" "ZLIB" "karchive" ];
    nativeBuildInputs = [ "cmake" ];
    propagatedBuildInputs = [ "Qt5Core" ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" ];
    propagatedUserEnvPkgs = [  ];
  };

  kauth = {
    buildInputs = [ "Qt5" "Qt5Test" "kcoreaddons" ];
    nativeBuildInputs = [ "cmake" ];
    propagatedBuildInputs = [ "kcoreaddons" ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" ];
    propagatedUserEnvPkgs = [  ];
  };

  kbookmarks = {
    buildInputs = [ "Qt5" "Qt5Test" "kconfigwidgets" "kcoreaddons" "kiconthemes" "kwidgetsaddons" "kxmlgui" ];
    nativeBuildInputs = [ "cmake" ];
    propagatedBuildInputs = [ "Qt5Widgets" "Qt5Xml" "kconfigwidgets" "kiconthemes" "kxmlgui" ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" ];
    propagatedUserEnvPkgs = [  ];
  };

  kcmutils = {
    buildInputs = [ "Qt5" "kconfigwidgets" "kcoreaddons" "kiconthemes" "kitemviews" "kservice" "kxmlgui" ];
    nativeBuildInputs = [ "cmake" "ki18n" ];
    propagatedBuildInputs = [ "kconfigwidgets" "kiconthemes" "kitemviews" "kservice" "kxmlgui" ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" ];
    propagatedUserEnvPkgs = [  ];
  };

  kcodecs = {
    buildInputs = [ "Qt5Core" "Qt5Test" ];
    nativeBuildInputs = [ "cmake" ];
    propagatedBuildInputs = [ "Qt5Core" ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" ];
    propagatedUserEnvPkgs = [  ];
  };

  kcompletion = {
    buildInputs = [ "Qt5" "Qt5Test" "kconfig" "kwidgetsaddons" ];
    nativeBuildInputs = [ "cmake" ];
    propagatedBuildInputs = [ "kconfig" "kwidgetsaddons" ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" ];
    propagatedUserEnvPkgs = [  ];
  };

  kconfig = {
    buildInputs = [ "Qt5" "Qt5Concurrent" "Qt5Core" "Qt5Gui" "Qt5Test" "Qt5Xml" ];
    nativeBuildInputs = [ "cmake" ];
    propagatedBuildInputs = [ "Qt5Xml" ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" ];
    propagatedUserEnvPkgs = [  ];
  };

  kconfigwidgets = {
    buildInputs = [ "Qt5" "kauth" "kcodecs" "kconfig" "kcoreaddons" "kguiaddons" "kwidgetsaddons" ];
    nativeBuildInputs = [ "cmake" "kdoctools" "ki18n" ];
    propagatedBuildInputs = [ "kauth" "kcodecs" "kconfig" "kguiaddons" "kwidgetsaddons" ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" "ki18n" ];
    propagatedUserEnvPkgs = [  ];
  };

  kcoreaddons = {
    buildInputs = [ "FAM" "Qt5" "Qt5Test" "Qt5Widgets" "SharedMimeInfo" ];
    nativeBuildInputs = [ "cmake" ];
    propagatedBuildInputs = [ "Qt5Core" ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" ];
    propagatedUserEnvPkgs = [ "SharedMimeInfo" ];
  };

  kcrash = {
    buildInputs = [ "Qt5" "Qt5Test" "Qt5Widgets" "Qt5X11Extras" "X11" "kcoreaddons" "kwindowsystem" ];
    nativeBuildInputs = [ "cmake" ];
    propagatedBuildInputs = [ "Qt5Core" "kcoreaddons" "kwindowsystem" ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" ];
    propagatedUserEnvPkgs = [  ];
  };

  kdbusaddons = {
    buildInputs = [ "Qt5DBus" "Qt5Test" "Qt5X11Extras" ];
    nativeBuildInputs = [ "cmake" ];
    propagatedBuildInputs = [ "Qt5DBus" ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" ];
    propagatedUserEnvPkgs = [  ];
  };

  kdeclarative = {
    buildInputs = [ "Qt5" "Qt5Test" "kconfig" "kcoreaddons" "kglobalaccel" "kguiaddons" "kiconthemes" "kio" "kwidgetsaddons" "kwindowsystem" ];
    nativeBuildInputs = [ "cmake" "ki18n" ];
    propagatedBuildInputs = [ "Qt5Qml" "kio" ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" ];
    propagatedUserEnvPkgs = [  ];
  };

  kded = {
    buildInputs = [ "Qt5" "kconfig" "kcoreaddons" "kcrash" "kdbusaddons" "kinit" "kservice" ];
    nativeBuildInputs = [ "cmake" "kdoctools" ];
    propagatedBuildInputs = [  ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" ];
    propagatedUserEnvPkgs = [  ];
  };

  kdelibs4support = {
    buildInputs = [ "AGG" "Blitz" "BlueZ" "DocBookXML4" "ENCHANT" "Eigen2" "FFmpeg" "Flac" "GObject" "GStreamer" "KDEWin" "LCMS" "LibArt" "NetworkManager" "OpenEXR" "OpenSSL" "PCRE" "QCA2" "QImageBlitz" "QNtrack" "Qt5" "Qt5X11Extras" "Sqlite" "USB" "X11" "Xine" "Xmms" "kcompletion" "kconfig" "kconfigwidgets" "kcrash" "kdesignerplugin" "kglobalaccel" "kguiaddons" "kiconthemes" "kio" "knotifications" "kparts" "kservice" "ktextwidgets" "kunitconversion" "kwidgetsaddons" "kwindowsystem" "kxmlgui" ];
    nativeBuildInputs = [ "cmake" "kdoctools" "ki18n" ];
    propagatedBuildInputs = [ "KDEWin" "Qt5DBus" "Qt5PrintSupport" "Qt5Xml" "kauth" "kconfigwidgets" "kcoreaddons" "kcrash" "kdelibs4support" "kdesignerplugin" "kemoticons" "kguiaddons" "kiconthemes" "kinit" "kitemmodels" "knotifications" "kparts" "ktextwidgets" "kunitconversion" "kwindowsystem" ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" "kdoctools" ];
    propagatedUserEnvPkgs = [  ];
  };

  kdesignerplugin = {
    buildInputs = [ "Qt5Core" "Qt5Designer" "Qt5Test" "Qt5Widgets" "kcompletion" "kconfig" "kconfigwidgets" "kcoreaddons" "kdewebkit" "kiconthemes" "kio" "kitemviews" "kplotting" "ktextwidgets" "kwidgetsaddons" "kxmlgui" "sonnet" ];
    nativeBuildInputs = [ "cmake" "kdoctools" ];
    propagatedBuildInputs = [  ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" ];
    propagatedUserEnvPkgs = [  ];
  };

  kdesu = {
    buildInputs = [ "Qt5Core" "X11" "kcoreaddons" "kpty" "kservice" ];
    nativeBuildInputs = [ "cmake" ];
    propagatedBuildInputs = [ "kpty" ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" ];
    propagatedUserEnvPkgs = [  ];
  };

  kdewebkit = {
    buildInputs = [ "Qt5" "kconfig" "kcoreaddons" "kio" "kjobwidgets" "kparts" "kservice" "kwallet" ];
    nativeBuildInputs = [ "cmake" ];
    propagatedBuildInputs = [ "Qt5WebKitWidgets" ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" ];
    propagatedUserEnvPkgs = [  ];
  };

  kdnssd = {
    buildInputs = [ "Avahi" "DNSSD" "Qt5" ];
    nativeBuildInputs = [ "cmake" ];
    propagatedBuildInputs = [ "Qt5Network" ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" ];
    propagatedUserEnvPkgs = [  ];
  };

  kdoctools = {
    buildInputs = [ "DocBookXML4" "DocBookXSL" "LibXml2" "Qt5Core" "karchive" ];
    nativeBuildInputs = [ "LibXslt" "cmake" "kdoctools" "ki18n" ];
    propagatedBuildInputs = [ "Qt5Core" "karchive" ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" ];
    propagatedUserEnvPkgs = [  ];
  };

  kemoticons = {
    buildInputs = [ "Qt5" "Qt5Test" "Qt5Xml" "karchive" "kconfig" "kservice" ];
    nativeBuildInputs = [ "cmake" ];
    propagatedBuildInputs = [ "Qt5Gui" "karchive" "kservice" ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" ];
    propagatedUserEnvPkgs = [  ];
  };

  kglobalaccel = {
    buildInputs = [ "Qt5" "X11" ];
    nativeBuildInputs = [ "cmake" ];
    propagatedBuildInputs = [ "Qt5DBus" "Qt5Widgets" ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" ];
    propagatedUserEnvPkgs = [  ];
  };

  kguiaddons = {
    buildInputs = [ "Qt5" "Qt5Gui" "Qt5X11Extras" "X11" "XCB" ];
    nativeBuildInputs = [ "cmake" ];
    propagatedBuildInputs = [ "Qt5Gui" ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" ];
    propagatedUserEnvPkgs = [  ];
  };

  khtml = {
    buildInputs = [ "GIF" "JPEG" "KDEWin" "OpenSSL" "PNG" "Phonon4Qt5" "Qt5" "Qt5Test" "Qt5X11Extras" "X11" "karchive" "kcodecs" "kglobalaccel" "kiconthemes" "kio" "kjs" "knotifications" "kparts" "ktextwidgets" "kwallet" "kwidgetsaddons" "kwindowsystem" "kxmlgui" "sonnet" ];
    nativeBuildInputs = [ "Perl" "cmake" "ki18n" ];
    propagatedBuildInputs = [ "Qt5Core" "karchive" "kbookmarks" "kglobalaccel" "kiconthemes" "kio" "kjs" "knotifications" "kparts" "kwallet" "kwidgetsaddons" "kwindowsystem" "sonnet" ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" "ki18n" ];
    propagatedUserEnvPkgs = [  ];
  };

  ki18n = {
    buildInputs = [ "LibIntl" "Qt5" ];
    nativeBuildInputs = [ "cmake" ];
    propagatedBuildInputs = [  ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" ];
    propagatedUserEnvPkgs = [  ];
  };

  kiconthemes = {
    buildInputs = [ "Qt5" "Qt5DBus" "Qt5Svg" "Qt5Widgets" "kconfigwidgets" "kitemviews" "kwidgetsaddons" ];
    nativeBuildInputs = [ "cmake" "ki18n" ];
    propagatedBuildInputs = [ "Qt5Widgets" "kconfigwidgets" "kitemviews" "kwidgetsaddons" ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" "ki18n" ];
    propagatedUserEnvPkgs = [  ];
  };

  kidletime = {
    buildInputs = [ "Qt5" "X11" "X11_XCB" "XCB" ];
    nativeBuildInputs = [ "cmake" ];
    propagatedBuildInputs = [ "Qt5Core" ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" ];
    propagatedUserEnvPkgs = [  ];
  };

  kimageformats = {
    buildInputs = [ "Jasper" "OpenEXR" "Qt5Gui" "Qt5PrintSupport" "Qt5Test" ];
    nativeBuildInputs = [ "cmake" ];
    propagatedBuildInputs = [  ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" ];
    propagatedUserEnvPkgs = [  ];
  };

  kinit = {
    buildInputs = [ "Libcap" "Qt5" "X11" "kconfig" "kcrash" "kio" "kservice" "kwindowsystem" ];
    nativeBuildInputs = [ "cmake" "kdoctools" "ki18n" ];
    propagatedBuildInputs = [  ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" ];
    propagatedUserEnvPkgs = [  ];
  };

  kio = {
    buildInputs = [ "ACL" "GSSAPI" "LibXml2" "OpenSSL" "Qt5" "Qt5Concurrent" "Qt5Core" "Qt5Script" "Qt5Test" "Qt5Widgets" "Strigi" "X11" "ZLIB" "karchive" "kbookmarks" "kcodecs" "kcompletion" "kconfig" "kconfigwidgets" "kcoreaddons" "kdbusaddons" "kiconthemes" "kitemviews" "kjobwidgets" "knotifications" "kservice" "kwallet" "kwidgetsaddons" "kwindowsystem" "kxmlgui" "solid" ];
    nativeBuildInputs = [ "LibXslt" "cmake" "kdoctools" "ki18n" ];
    propagatedBuildInputs = [ "Qt5Network" "kbookmarks" "kcompletion" "kitemviews" "kjobwidgets" "kservice" "kxmlgui" "solid" ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" ];
    propagatedUserEnvPkgs = [  ];
  };

  kitemmodels = {
    buildInputs = [ "Grantlee" "Qt5" "Qt5Core" "Qt5Script" ];
    nativeBuildInputs = [ "cmake" ];
    propagatedBuildInputs = [ "Qt5Core" ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" ];
    propagatedUserEnvPkgs = [  ];
  };

  kitemviews = {
    buildInputs = [ "Qt5" ];
    nativeBuildInputs = [ "cmake" ];
    propagatedBuildInputs = [ "Qt5Widgets" ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" ];
    propagatedUserEnvPkgs = [  ];
  };

  kjobwidgets = {
    buildInputs = [ "Qt5" "Qt5X11Extras" "X11" "kcoreaddons" "kwidgetsaddons" ];
    nativeBuildInputs = [ "cmake" ];
    propagatedBuildInputs = [ "Qt5Widgets" "kcoreaddons" "kwidgetsaddons" ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" ];
    propagatedUserEnvPkgs = [  ];
  };

  kjs = {
    buildInputs = [ "PCRE" "Qt5Core" "Qt5Test" ];
    nativeBuildInputs = [ "Perl" "cmake" ];
    propagatedBuildInputs = [ "Qt5Core" ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" ];
    propagatedUserEnvPkgs = [  ];
  };

  kjsembed = {
    buildInputs = [ "Qt5" "kjs" ];
    nativeBuildInputs = [ "cmake" "kdoctools" "ki18n" ];
    propagatedBuildInputs = [ "kjs" ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" "ki18n" ];
    propagatedUserEnvPkgs = [  ];
  };

  kmediaplayer = {
    buildInputs = [ "Qt5DBus" "Qt5Test" "Qt5Widgets" "kparts" "kxmlgui" ];
    nativeBuildInputs = [ "cmake" ];
    propagatedBuildInputs = [ "kparts" ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" ];
    propagatedUserEnvPkgs = [  ];
  };

  knewstuff = {
    buildInputs = [ "Qt5" "Qt5Test" "attica" "karchive" "kcompletion" "kconfig" "kcoreaddons" "kiconthemes" "kio" "kitemviews" "ktextwidgets" "kwidgetsaddons" "kxmlgui" ];
    nativeBuildInputs = [ "cmake" "ki18n" ];
    propagatedBuildInputs = [ "Qt5Widgets" "attica" "karchive" "kio" "kxmlgui" ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" ];
    propagatedUserEnvPkgs = [  ];
  };

  knotifications = {
    buildInputs = [ "Phonon4Qt5" "Qt5" "Qt5X11Extras" "X11" "dbusmenu-qt5" "kcodecs" "kconfig" "kcoreaddons" "kiconthemes" "kservice" "kwindowsystem" ];
    nativeBuildInputs = [ "cmake" ];
    propagatedBuildInputs = [ "Qt5Widgets" "kwindowsystem" ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" ];
    propagatedUserEnvPkgs = [  ];
  };

  knotifyconfig = {
    buildInputs = [ "Phonon4Qt5" "Qt5" "Qt5Test" "kcompletion" "kconfig" "kconfigwidgets" "kio" "knotifications" "kservice" "kwidgetsaddons" "kxmlgui" ];
    nativeBuildInputs = [ "cmake" "ki18n" ];
    propagatedBuildInputs = [ "Qt5Widgets" "kio" ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" "ki18n" ];
    propagatedUserEnvPkgs = [  ];
  };

  kparts = {
    buildInputs = [ "Qt5" "Qt5Test" "kconfig" "kcoreaddons" "kiconthemes" "kio" "kjobwidgets" "knotifications" "kservice" "ktextwidgets" "kwidgetsaddons" "kxmlgui" ];
    nativeBuildInputs = [ "cmake" "ki18n" ];
    propagatedBuildInputs = [ "kio" "knotifications" "ktextwidgets" "kxmlgui" ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" ];
    propagatedUserEnvPkgs = [  ];
  };

  kplotting = {
    buildInputs = [ "Qt5" "Qt5Widgets" ];
    nativeBuildInputs = [ "cmake" ];
    propagatedBuildInputs = [ "Qt5Widgets" ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" ];
    propagatedUserEnvPkgs = [  ];
  };

  kpty = {
    buildInputs = [ "Qt5" "kcoreaddons" ];
    nativeBuildInputs = [ "cmake" "ki18n" ];
    propagatedBuildInputs = [ "kcoreaddons" ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" "ki18n" ];
    propagatedUserEnvPkgs = [  ];
  };

  kross = {
    buildInputs = [ "Qt5" "kcompletion" "kcoreaddons" "kiconthemes" "kio" "kparts" "kservice" "kwidgetsaddons" "kxmlgui" ];
    nativeBuildInputs = [ "cmake" "kdoctools" "ki18n" ];
    propagatedBuildInputs = [ "Qt5Script" "Qt5Widgets" "Qt5Xml" "kiconthemes" "kio" "kparts" "kwidgetsaddons" ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" "ki18n" ];
    propagatedUserEnvPkgs = [  ];
  };

  krunner = {
    buildInputs = [ "Qt5" "kconfig" "kcoreaddons" "kio" "kservice" "plasma-framework" "solid" "threadweaver" ];
    nativeBuildInputs = [ "cmake" "ki18n" ];
    propagatedBuildInputs = [ "Qt5Core" "plasma-framework" ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" ];
    propagatedUserEnvPkgs = [  ];
  };

  kservice = {
    buildInputs = [ "Qt5" "kconfig" "kcoreaddons" "kcrash" "kdbusaddons" "kservice" ];
    nativeBuildInputs = [ "cmake" "kdoctools" "ki18n" ];
    propagatedBuildInputs = [ "kconfig" "kcoreaddons" "kdbusaddons" ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" "ki18n" ];
    propagatedUserEnvPkgs = [  ];
  };

  ktexteditor = {
    buildInputs = [ "LibGit2" "Qt5" "karchive" "kconfig" "kguiaddons" "kio" "kparts" "sonnet" ];
    nativeBuildInputs = [ "Perl" "cmake" "ki18n" ];
    propagatedBuildInputs = [  ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" ];
    propagatedUserEnvPkgs = [  ];
  };

  ktextwidgets = {
    buildInputs = [ "Qt5" "kcompletion" "kconfig" "kconfigwidgets" "kiconthemes" "kservice" "kwidgetsaddons" "kwindowsystem" "sonnet" ];
    nativeBuildInputs = [ "cmake" "ki18n" ];
    propagatedBuildInputs = [ "Qt5Widgets" "kcompletion" "kconfigwidgets" "kiconthemes" "kservice" "kwindowsystem" "sonnet" ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" "ki18n" ];
    propagatedUserEnvPkgs = [  ];
  };

  kunitconversion = {
    buildInputs = [ "Qt5" ];
    nativeBuildInputs = [ "cmake" "ki18n" ];
    propagatedBuildInputs = [ "Qt5Core" "kconfig" ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" "ki18n" ];
    propagatedUserEnvPkgs = [  ];
  };

  kwallet = {
    buildInputs = [ "Gpgme" "KF5Gpgmepp" "LibGcrypt" "Qt5" "kconfig" "kcoreaddons" "kdbusaddons" "kiconthemes" "knotifications" "kservice" "kwidgetsaddons" "kwindowsystem" ];
    nativeBuildInputs = [ "cmake" "ki18n" ];
    propagatedBuildInputs = [ "Qt5Core" "kconfig" "kwindowsystem" ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" ];
    propagatedUserEnvPkgs = [  ];
  };

  kwidgetsaddons = {
    buildInputs = [ "Qt5" ];
    nativeBuildInputs = [ "cmake" ];
    propagatedBuildInputs = [ "Qt5Widgets" ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" ];
    propagatedUserEnvPkgs = [  ];
  };

  kwindowsystem = {
    buildInputs = [ "Qt5" "Qt5WinExtras" "X11" "XCB" ];
    nativeBuildInputs = [ "cmake" ];
    propagatedBuildInputs = [ "Qt5Widgets" ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" ];
    propagatedUserEnvPkgs = [  ];
  };

  kxmlgui = {
    buildInputs = [ "Qt5" "attica" "kconfig" "kconfigwidgets" "kglobalaccel" "kiconthemes" "kitemviews" "ktextwidgets" "kwidgetsaddons" "kwindowsystem" ];
    nativeBuildInputs = [ "cmake" "ki18n" ];
    propagatedBuildInputs = [ "Qt5DBus" "Qt5Xml" "attica" "kconfig" "kconfigwidgets" "kglobalaccel" "kiconthemes" "kitemviews" "ktextwidgets" "kwindowsystem" ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" ];
    propagatedUserEnvPkgs = [  ];
  };

  plasma-framework = {
    buildInputs = [ "EGL" "Gpgme" "KActivities" "KCoreAddons" "KDE4Support" "KDESu" "KDeclarative" "KF5" "KF5KArchive" "KF5KAuth" "KF5KBookmarks" "KF5KCodecs" "KF5KCompletion" "KF5KConfig" "KF5KConfigWidgets" "KF5KCoreAddons" "KF5KCrash" "KF5KDBusAddons" "KF5KDESu" "KF5KDeclarative" "KF5KDocTools" "KF5KF5GlobalAccel" "KF5KGuiAddons" "KF5KI18n" "KF5KIconThemes" "KF5KIdleTime" "KF5KInit" "KF5KJS" "KF5KJobWidgets" "KF5KNotifications" "KF5KParts" "KF5KService" "KF5KTextWidgets" "KF5KUnitConversion" "KF5KWallet" "KF5KWidgetsAddons" "KF5KWindowSystem" "KF5NO_MODULE" "KdepimLibs" "OpenGL" "QCA2" "Qt5" "Qt5Test" "Qt5Widgets" "Solid" "X11" "XCB" "kactivities" "karchive" "kauth" "kbookmarks" "kcodecs" "kcompletion" "kconfig" "kconfigwidgets" "kcoreaddons" "kcrash" "kdbusaddons" "kdeclarative" "kdelibs4support" "kdesu" "kglobalaccel" "kguiaddons" "kiconthemes" "kidletime" "kinit" "kio" "kitemmodels" "kitemviews" "kjobwidgets" "kjs" "knotifications" "kparts" "kross" "kservice" "ktextwidgets" "kunitconversion" "kwallet" "kwidgetsaddons" "kwindowsystem" "kxmlgui" "solid" "sonnet" "threadweaver" ];
    nativeBuildInputs = [ "SH" "cmake" "kdoctools" "ki18n" ];
    propagatedBuildInputs = [  ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" ];
    propagatedUserEnvPkgs = [  ];
  };

  solid = {
    buildInputs = [ "IOKit" "MediaPlayerInfo" "Qt5" "Qt5Qml" "UDev" ];
    nativeBuildInputs = [ "BISON" "FLEX" "cmake" ];
    propagatedBuildInputs = [ "Qt5Core" ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" ];
    propagatedUserEnvPkgs = [  ];
  };

  sonnet = {
    buildInputs = [ "ASPELL" "ENCHANT" "HSPELL" "HUNSPELL" "Qt5" "Qt5Test" "ZLIB" ];
    nativeBuildInputs = [ "cmake" ];
    propagatedBuildInputs = [ "Qt5Core" ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" ];
    propagatedUserEnvPkgs = [  ];
  };

  threadweaver = {
    buildInputs = [ "Qt5" "Qt5Core" "Qt5Test" "Qt5Widgets" "threadweaver" ];
    nativeBuildInputs = [ "SNIPPETEXTRACTOR" "cmake" ];
    propagatedBuildInputs = [ "Qt5Core" ];
    propagatedNativeBuildInputs = [ "extra-cmake-modules" ];
    propagatedUserEnvPkgs = [  ];
  };

}
