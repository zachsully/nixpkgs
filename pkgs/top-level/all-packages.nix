/* This file composes the Nix Packages collection.  That is, it
   imports the functions that build the various packages, and calls
   them with appropriate arguments.  The result is a set of all the
   packages in the Nix Packages collection for some particular
   platform. */


{ # The system (e.g., `i686-linux') for which to build the packages.
  system ? builtins.currentSystem

, # The standard environment to use.  Only used for bootstrapping.  If
  # null, the default standard environment is used.
  bootStdenv ? null

, # Non-GNU/Linux OSes are currently "impure" platforms, with their libc
  # outside of the store.  Thus, GCC, GFortran, & co. must always look for
  # files in standard system directories (/usr/include, etc.)
  noSysDirs ? (system != "x86_64-darwin"
               && system != "x86_64-freebsd" && system != "i686-freebsd"
               && system != "x86_64-kfreebsd-gnu")

  # More flags for the bootstrapping of stdenv.
, gccWithCC ? true
, gccWithProfiling ? true

, # Allow a configuration attribute set to be passed in as an
  # argument.  Otherwise, it's read from $NIXPKGS_CONFIG or
  # ~/.nixpkgs/config.nix.
  config ? null

, crossSystem ? null
, platform ? null
}:


let config_ = config; platform_ = platform; in # rename the function arguments

let

  lib = import ../../lib;

  # The contents of the configuration file found at $NIXPKGS_CONFIG or
  # $HOME/.nixpkgs/config.nix.
  # for NIXOS (nixos-rebuild): use nixpkgs.config option
  config =
    let
      toPath = builtins.toPath;
      getEnv = x: if builtins ? getEnv then builtins.getEnv x else "";
      pathExists = name:
        builtins ? pathExists && builtins.pathExists (toPath name);

      configFile = getEnv "NIXPKGS_CONFIG";
      homeDir = getEnv "HOME";
      configFile2 = homeDir + "/.nixpkgs/config.nix";

      configExpr =
        if config_ != null then config_
        else if configFile != "" && pathExists configFile then import (toPath configFile)
        else if homeDir != "" && pathExists configFile2 then import (toPath configFile2)
        else {};

    in
      # allow both:
      # { /* the config */ } and
      # { pkgs, ... } : { /* the config */ }
      if builtins.isFunction configExpr
        then configExpr { inherit pkgs; }
        else configExpr;

  # Allow setting the platform in the config file. Otherwise, let's use a reasonable default (pc)

  platformAuto = let
      platforms = (import ./platforms.nix);
    in
      if system == "armv6l-linux" then platforms.raspberrypi
      else if system == "armv5tel-linux" then platforms.sheevaplug
      else if system == "mips64el-linux" then platforms.fuloong2f_n32
      else if system == "x86_64-linux" then platforms.pc64
      else if system == "i686-linux" then platforms.pc32
      else platforms.pcBase;

  platform = if platform_ != null then platform_
    else config.platform or platformAuto;

  # Helper functions that are exported through `pkgs'.
  helperFunctions =
    stdenvAdapters //
    (import ../build-support/trivial-builders.nix { inherit lib; inherit (pkgs) stdenv; inherit (pkgs.xorg) lndir; });

  stdenvAdapters =
    import ../stdenv/adapters.nix pkgs;


  # Allow packages to be overriden globally via the `packageOverrides'
  # configuration option, which must be a function that takes `pkgs'
  # as an argument and returns a set of new or overriden packages.
  # The `packageOverrides' function is called with the *original*
  # (un-overriden) set of packages, allowing packageOverrides
  # attributes to refer to the original attributes (e.g. "foo =
  # ... pkgs.foo ...").
  pkgs = applyGlobalOverrides (config.packageOverrides or (pkgs: {}));


  # Return the complete set of packages, after applying the overrides
  # returned by the `overrider' function (see above).  Warning: this
  # function is very expensive!
  applyGlobalOverrides = overrider:
    let
      # Call the overrider function.  We don't want stdenv overrides
      # in the case of cross-building, or otherwise the basic
      # overrided packages will not be built with the crossStdenv
      # adapter.
      overrides = overrider pkgsOrig //
        (lib.optionalAttrs (pkgsOrig.stdenv ? overrides && crossSystem == null) (pkgsOrig.stdenv.overrides pkgsOrig));

      # The un-overriden packages, passed to `overrider'.
      pkgsOrig = pkgsFun pkgs {};

      # The overriden, final packages.
      pkgs = pkgsFun pkgs overrides;
    in pkgs;


  # The package compositions.  Yes, this isn't properly indented.
  pkgsFun = pkgs: overrides:
    with helperFunctions;
    let defaultScope = pkgs // pkgs.xorg; self = self_ // overrides;
    self_ = with self; helperFunctions // {

  # Make some arguments passed to all-packages.nix available
  inherit system platform;

  # Allow callPackage to fill in the pkgs argument
  inherit pkgs;


  # We use `callPackage' to be able to omit function arguments that
  # can be obtained from `pkgs' or `pkgs.xorg' (i.e. `defaultScope').
  # Use `newScope' for sets of packages in `pkgs' (see e.g. `gnome'
  # below).
  callPackage = newScope {};

  newScope = extra: lib.callPackageWith (defaultScope // extra);


  # Override system. This is useful to build i686 packages on x86_64-linux.
  forceSystem = system: kernel: (import ./all-packages.nix) {
    inherit system;
    platform = platform // { kernelArch = kernel; };
    inherit bootStdenv noSysDirs gccWithCC gccWithProfiling config
      crossSystem;
  };


  # Used by wine, firefox with debugging version of Flash, ...
  pkgsi686Linux = forceSystem "i686-linux" "i386";

  callPackage_i686 = lib.callPackageWith (pkgsi686Linux // pkgsi686Linux.xorg);


  # For convenience, allow callers to get the path to Nixpkgs.
  path = ../..;


  ### Symbolic names.

  x11 = xlibsWrapper;

  # `xlibs' is the set of X library components.  This used to be the
  # old modular X libraries project (called `xlibs') but now it's just
  # the set of packages in the modular X.org tree (which also includes
  # non-library components like the server, drivers, fonts, etc.).
  xlibs = xorg // {xlibs = xlibsWrapper;};


  ### Helper functions.

  inherit lib config stdenvAdapters;

  inherit (lib) lowPrio hiPrio appendToName makeOverridable;
  inherit (misc) versionedDerivation;

  # Applying this to an attribute set will cause nix-env to look
  # inside the set for derivations.
  recurseIntoAttrs = attrs: attrs // { recurseForDerivations = true; };

  builderDefs = lib.composedArgsAndFun (import ../build-support/builder-defs/builder-defs.nix) {
    inherit stringsWithDeps lib stdenv writeScript
      fetchurl fetchmtn fetchgit;
  };

  builderDefsPackage = builderDefs.builderDefsPackage builderDefs;

  stringsWithDeps = lib.stringsWithDeps;


  ### Nixpkgs maintainer tools

  nix-generate-from-cpan = callPackage ../../maintainers/scripts/nix-generate-from-cpan.nix { };

  nixpkgs-lint = callPackage ../../maintainers/scripts/nixpkgs-lint.nix { };


  ### STANDARD ENVIRONMENT


  allStdenvs = import ../stdenv {
    inherit system platform config lib;
    allPackages = args: import ./all-packages.nix ({ inherit config system; } // args);
  };

  defaultStdenv = allStdenvs.stdenv // { inherit platform; };

  stdenvCross = lowPrio (makeStdenvCross defaultStdenv crossSystem binutilsCross gccCrossStageFinal);

  stdenv =
    if bootStdenv != null then (bootStdenv // {inherit platform;}) else
      if crossSystem != null then
        stdenvCross
      else
        let
            changer = config.replaceStdenv or null;
        in if changer != null then
          changer {
            # We import again all-packages to avoid recursivities.
            pkgs = import ./all-packages.nix {
              # We remove packageOverrides to avoid recursivities
              config = removeAttrs config [ "replaceStdenv" ];
            };
          }
      else
        defaultStdenv;

  forceNativeDrv = drv : if crossSystem == null then drv else
    (drv // { crossDrv = drv.nativeDrv; });

  # A stdenv capable of building 32-bit binaries.  On x86_64-linux,
  # it uses GCC compiled with multilib support; on i686-linux, it's
  # just the plain stdenv.
  stdenv_32bit = lowPrio (
    if system == "x86_64-linux" then
      overrideGCC stdenv gcc48_multi
    else
      stdenv);


  ### BUILD SUPPORT

  attrSetToDir = arg: import ../build-support/upstream-updater/attrset-to-dir.nix {
    inherit writeTextFile stdenv lib;
    theAttrSet = arg;
  };

  autoreconfHook = makeSetupHook
    { substitutions = { inherit autoconf automake libtool; }; }
    ../build-support/setup-hooks/autoreconf.sh;

  buildEnv = import ../build-support/buildenv {
    inherit (pkgs) runCommand perl;
  };

  buildFHSChrootEnv = import ../build-support/build-fhs-chrootenv {
    inherit buildEnv system;
    inherit stdenv glibc glibc_multi glibcLocales;
    inherit bashInteractive coreutils less shadow su;
    inherit gawk gcc gcc_multi diffutils findutils gnused gnugrep;
    inherit gnutar gzip bzip2 xz;

    nixpkgs      = pkgs;
    nixpkgs_i686 = pkgsi686Linux;
  };

  dotnetenv = import ../build-support/dotnetenv {
    inherit stdenv;
    dotnetfx = dotnetfx40;
  };

  scatterOutputHook = makeSetupHook {} ../build-support/setup-hooks/scatter_output.sh;

  vsenv = callPackage ../build-support/vsenv {
    vs = vs90wrapper;
  };

  fetchadc = import ../build-support/fetchadc {
    inherit curl stdenv;
    adc_user = if config ? adc_user
      then config.adc_user
      else throw "You need an adc_user attribute in your config to download files from Apple Developer Connection";
    adc_pass = if config ? adc_pass
      then config.adc_pass
      else throw "You need an adc_pass attribute in your config to download files from Apple Developer Connection";
  };

  fetchbower = import ../build-support/fetchbower {
    inherit stdenv git;
    inherit (nodePackages) fetch-bower;
  };

  fetchbzr = import ../build-support/fetchbzr {
    inherit stdenv bazaar;
  };

  fetchcvs = import ../build-support/fetchcvs {
    inherit stdenv cvs;
  };

  fetchdarcs = import ../build-support/fetchdarcs {
    inherit stdenv darcs nix;
  };

  fetchgit = import ../build-support/fetchgit {
    inherit stdenv cacert;
    git = gitMinimal;
  };

  fetchgitPrivate = import ../build-support/fetchgit/private.nix {
    inherit fetchgit writeScript openssh stdenv;
  };

  fetchgitrevision = import ../build-support/fetchgitrevision runCommand git;

  fetchmtn = callPackage ../build-support/fetchmtn (config.fetchmtn or {});

  packer = callPackage ../development/tools/packer { };

  fetchpatch = callPackage ../build-support/fetchpatch { };

  fetchsvn = import ../build-support/fetchsvn {
    inherit stdenv subversion openssh;
    sshSupport = true;
  };

  fetchsvnrevision = import ../build-support/fetchsvnrevision runCommand subversion;

  fetchsvnssh = import ../build-support/fetchsvnssh {
    inherit stdenv subversion openssh expect;
    sshSupport = true;
  };

  fetchhg = import ../build-support/fetchhg {
    inherit stdenv mercurial nix;
  };

  # `fetchurl' downloads a file from the network.
  fetchurl = import ../build-support/fetchurl {
    inherit curl stdenv;
  };

  # A wrapper around fetchurl that generates miror://gnome URLs automatically
  fetchurlGnome = callPackage ../build-support/fetchurl/gnome.nix { };

  # fetchurlBoot is used for curl and its dependencies in order to
  # prevent a cyclic dependency (curl depends on curl.tar.bz2,
  # curl.tar.bz2 depends on fetchurl, fetchurl depends on curl).  It
  # uses the curl from the previous bootstrap phase (e.g. a statically
  # linked curl in the case of stdenv-linux).
  fetchurlBoot = stdenv.fetchurlBoot;

  fetchzip = import ../build-support/fetchzip { inherit lib fetchurl unzip; };

  fetchFromGitHub = { owner, repo, rev, sha256 }: fetchzip {
    name = "${repo}-${rev}-src";
    url = "https://github.com/${owner}/${repo}/archive/${rev}.tar.gz";
    inherit sha256;
  };

  resolveMirrorURLs = {url}: fetchurl {
    showURLs = true;
    inherit url;
  };

  libredirect = callPackage ../build-support/libredirect { };

  makeDesktopItem = import ../build-support/make-desktopitem {
    inherit stdenv;
  };

  makeAutostartItem = import ../build-support/make-startupitem {
    inherit stdenv;
    inherit lib;
  };

  makeInitrd = {contents, compressor ? "gzip -9"}:
    import ../build-support/kernel/make-initrd.nix {
      inherit stdenv perl perlArchiveCpio cpio contents ubootChooser compressor;
    };

  makeWrapper = makeSetupHook { } ../build-support/setup-hooks/make-wrapper.sh;

  makeModulesClosure = { kernel, rootModules, allowMissing ? false }:
    import ../build-support/kernel/modules-closure.nix {
      inherit stdenv kmod kernel nukeReferences rootModules allowMissing;
    };

  pathsFromGraph = ../build-support/kernel/paths-from-graph.pl;

  srcOnly = args: (import ../build-support/src-only) ({inherit stdenv; } // args);

  substituteAll = import ../build-support/substitute/substitute-all.nix {
    inherit stdenv;
  };

  substituteAllFiles = import ../build-support/substitute-files/substitute-all-files.nix {
    inherit stdenv;
  };

  replaceDependency = import ../build-support/replace-dependency.nix {
    inherit runCommand nix lib;
  };

  nukeReferences = callPackage ../build-support/nuke-references/default.nix { };

  vmTools = import ../build-support/vm/default.nix {
    inherit pkgs;
  };

  releaseTools = import ../build-support/release/default.nix {
    inherit pkgs;
  };

  composableDerivation = (import ../../lib/composable-derivation.nix) {
    inherit pkgs lib;
  };

  platforms = import ./platforms.nix;

  setJavaClassPath = makeSetupHook { } ../build-support/setup-hooks/set-java-classpath.sh;

  fixDarwinDylibNames = makeSetupHook { } ../build-support/setup-hooks/fix-darwin-dylib-names.sh;

  keepBuildTree = makeSetupHook { } ../build-support/setup-hooks/keep-build-tree.sh;

  enableGCOVInstrumentation = makeSetupHook { } ../build-support/setup-hooks/enable-coverage-instrumentation.sh;

  makeGCOVReport = makeSetupHook
    { deps = [ pkgs.lcov pkgs.enableGCOVInstrumentation ]; }
    ../build-support/setup-hooks/make-coverage-analysis-report.sh;

  # intended to be used like nix-build -E 'with <nixpkgs> {}; enableDebugging fooPackage'
  enableDebugging = pkg : pkg.override { stdenv = stdenvAdapters.keepDebugInfo pkg.stdenv; };

  ### TOOLS

  abduco = callPackage ../tools/misc/abduco { };

  acct = callPackage ../tools/system/acct { };

  acoustidFingerprinter = callPackage ../tools/audio/acoustid-fingerprinter {
    ffmpeg = ffmpeg_1;
  };

  actdiag = pythonPackages.actdiag;

  adom = callPackage ../games/adom { };

  advancecomp = callPackage ../tools/compression/advancecomp {};

  aefs = callPackage ../tools/filesystems/aefs { };

  aegisub = callPackage ../applications/video/aegisub {
    wxGTK = wxGTK30;
  };

  aespipe = callPackage ../tools/security/aespipe { };

  aescrypt = callPackage ../tools/misc/aescrypt { };

  ahcpd = callPackage ../tools/networking/ahcpd { };

  aide = callPackage ../tools/security/aide { };

  aircrackng = callPackage ../tools/networking/aircrack-ng { };

  airfield = callPackage ../tools/networking/airfield { };

  analog = callPackage ../tools/admin/analog {};

  apktool = callPackage ../development/tools/apktool {
    buildTools = androidenv.buildTools;
  };

  apt-offline = callPackage ../tools/misc/apt-offline { };

  apulse = callPackage ../misc/apulse { };

  archivemount = callPackage ../tools/filesystems/archivemount { };

  arandr = callPackage ../tools/X11/arandr { };

  arcanist = callPackage ../development/tools/misc/arcanist {};

  arduino_core = callPackage ../development/arduino/arduino-core {
    jdk = jdk;
    jre = jdk;
  };

  argyllcms = callPackage ../tools/graphics/argyllcms {};

  arp-scan = callPackage ../tools/misc/arp-scan { };

  ascii = callPackage ../tools/text/ascii { };

  asymptote = builderDefsPackage ../tools/graphics/asymptote {
    inherit freeglut ghostscriptX imagemagick fftw boehmgc
      mesa ncurses readline gsl libsigsegv python zlib perl
      texinfo xz;
    texLive = texLiveAggregationFun {
      paths = [ texLive texLiveExtra texLiveCMSuper ];
    };
  };

  awscli = callPackage ../tools/admin/awscli { };

  ec2_api_tools = callPackage ../tools/virtualization/ec2-api-tools { };

  ec2_ami_tools = callPackage ../tools/virtualization/ec2-ami-tools { };

  altermime = callPackage ../tools/networking/altermime {};

  amule = callPackage ../tools/networking/p2p/amule { };

  amuleDaemon = appendToName "daemon" (amule.override {
    monolithic = false;
    daemon = true;
  });

  amuleGui = appendToName "gui" (amule.override {
    monolithic = false;
    client = true;
  });

  androidenv = import ../development/mobile/androidenv {
    inherit pkgs;
    pkgs_i686 = pkgsi686Linux;
  };

  apg = callPackage ../tools/security/apg { };

  grc = callPackage ../tools/misc/grc { };

  otool = callPackage ../os-specific/darwin/otool { };

  pass = callPackage ../tools/security/pass {
    gnupg = gnupg1compat;
  };

  setfile = callPackage ../os-specific/darwin/setfile { };

  install_name_tool = callPackage ../os-specific/darwin/install_name_tool { };

  xcodeenv = callPackage ../development/mobile/xcodeenv { };

  titaniumenv = callPackage ../development/mobile/titaniumenv {
    inherit pkgs;
    pkgs_i686 = pkgsi686Linux;
  };

  inherit (androidenv) androidsdk_4_4 androidndk;

  aria2 = callPackage ../tools/networking/aria2 { };
  aria = aria2;

  at = callPackage ../tools/system/at { };

  atftp = callPackage ../tools/networking/atftp {};

  autogen = callPackage ../development/tools/misc/autogen { };

  autojump = callPackage ../tools/misc/autojump { };

  autorandr = callPackage ../tools/misc/autorandr {
    inherit (xorg) xrandr xdpyinfo;
  };

  avahi = callPackage ../development/libraries/avahi {
    qt4Support = config.avahi.qt4Support or false;
  };

  aws = callPackage ../tools/virtualization/aws { };

  aws_mturk_clt = callPackage ../tools/misc/aws-mturk-clt { };

  axel = callPackage ../tools/networking/axel { };

  azureus = callPackage ../tools/networking/p2p/azureus { };

  basex = callPackage ../tools/text/xml/basex { };

  babeld = callPackage ../tools/networking/babeld { };

  badvpn = callPackage ../tools/networking/badvpn {};

  banner = callPackage ../games/banner {};

  barcode = callPackage ../tools/graphics/barcode {};

  bashmount = callPackage ../tools/filesystems/bashmount {};

  bc = callPackage ../tools/misc/bc { };

  bcache-tools = callPackage ../tools/filesystems/bcache-tools { };

  bchunk = callPackage ../tools/cd-dvd/bchunk { };

  bfr = callPackage ../tools/misc/bfr { };

  bindfs = callPackage ../tools/filesystems/bindfs { };

  binwalk = callPackage ../tools/misc/binwalk {
    python = pythonFull;
    wrapPython = pythonPackages.wrapPython;
    curses = pythonPackages.curses;
  };

  binwalk-full = callPackage ../tools/misc/binwalk {
    python = pythonFull;
    wrapPython = pythonPackages.wrapPython;
    curses = pythonPackages.curses;
    visualizationSupport = true;
    pyqtgraph = pythonPackages.pyqtgraph;
  };

  bitbucket-cli = pythonPackages.bitbucket-cli;

  blink = callPackage ../applications/networking/instant-messengers/blink { };

  blitz = callPackage ../development/libraries/blitz { };

  blockdiag = pythonPackages.blockdiag;

  bmon = callPackage ../tools/misc/bmon { };

  bochs = callPackage ../applications/virtualization/bochs { };

  boomerang = callPackage ../development/tools/boomerang { };

  boost-build = callPackage ../development/tools/boost-build { };

  bootchart = callPackage ../tools/system/bootchart { };

  bro = callPackage ../applications/networking/ids/bro { };

  bsod = callPackage ../misc/emulators/bsod { };

  btrfsProgs = callPackage ../tools/filesystems/btrfsprogs { };
  btrfsProgs-3_16 = callPackage ../tools/filesystems/btrfsprogs/3.16.nix { };

  bwm_ng = callPackage ../tools/networking/bwm-ng { };

  byobu = callPackage ../tools/misc/byobu { };

  capstone = callPackage ../development/libraries/capstone { };

  catdoc = callPackage ../tools/text/catdoc { };

  ccnet = callPackage ../tools/networking/ccnet { };

  consul = callPackage ../servers/consul {
    inherit ruby rubyLibs;
  };

  consul_ui = consul.ui;

  corosync = callPackage ../servers/corosync { };

  chntpw = callPackage ../tools/security/chntpw { };

  coprthr = callPackage ../development/libraries/coprthr {
    flex = flex_2_5_35;
  };

  crawlTiles = callPackage ../games/crawl { };

  crawl = callPackage ../games/crawl {
    tileMode = false;
  };

  cv = callPackage ../tools/misc/cv { };

  datamash = callPackage ../tools/misc/datamash { };

  direnv = callPackage ../tools/misc/direnv { };

  discount = callPackage ../tools/text/discount { };

  ditaa = callPackage ../tools/graphics/ditaa { };

  dlx = callPackage ../misc/emulators/dlx { };

  duperemove = callPackage ../tools/filesystems/duperemove {
    linuxHeaders = linuxHeaders_3_14;
  };

  eggdrop = callPackage ../tools/networking/eggdrop { };

  enca = callPackage ../tools/text/enca { };

  fasd = callPackage ../tools/misc/fasd {
    inherit (haskellPackages) pandoc;
  };

  fop = callPackage ../tools/typesetting/fop { };

  gist = callPackage ../tools/text/gist { };

  mcrl = callPackage ../tools/misc/mcrl { };

  mcrl2 = callPackage ../tools/misc/mcrl2 { };

  mpdcron = callPackage ../tools/audio/mpdcron { };

  syslogng = callPackage ../tools/system/syslog-ng { };

  syslogng_incubator = callPackage ../tools/system/syslog-ng-incubator { };

  rsyslog = callPackage ../tools/system/rsyslog { };

  mcrypt = callPackage ../tools/misc/mcrypt { };

  mstflint = callPackage ../tools/misc/mstflint { };

  mcelog = callPackage ../os-specific/linux/mcelog { };

  apparix = callPackage ../tools/misc/apparix { };

  appdata-tools = callPackage ../tools/misc/appdata-tools { };

  asciidoc = callPackage ../tools/typesetting/asciidoc {
    inherit (pythonPackages) matplotlib numpy aafigure recursivePthLoader;
    enableStandardFeatures = false;
  };

  asciidoc-full = appendToName "full" (asciidoc.override {
    inherit (pythonPackages) pygments;
    enableStandardFeatures = true;
  });

  autossh = callPackage ../tools/networking/autossh { };

  bacula = callPackage ../tools/backup/bacula { };

  bareos = callPackage ../tools/backup/bareos { };

  beanstalkd = callPackage ../servers/beanstalkd { };

  bgs = callPackage ../tools/X11/bgs { };

  biber = callPackage ../tools/typesetting/biber {
    inherit (perlPackages)
      autovivification BusinessISBN BusinessISMN BusinessISSN ConfigAutoConf
      DataCompare DataDump DateSimple EncodeEUCJPASCII EncodeHanExtra EncodeJIS2K
      ExtUtilsLibBuilder FileSlurp IPCRun3 Log4Perl LWPProtocolHttps ListAllUtils
      ListMoreUtils ModuleBuild MozillaCA ReadonlyXS RegexpCommon TextBibTeX
      UnicodeCollate UnicodeLineBreak URI XMLLibXMLSimple XMLLibXSLT XMLWriter;
  };

  bibtextools = callPackage ../tools/typesetting/bibtex-tools {
    inherit (strategoPackages016) strategoxt sdf;
  };

  bittornado = callPackage ../tools/networking/p2p/bit-tornado { };

  blueman = callPackage ../tools/bluetooth/blueman {
    inherit (pythonPackages) notify;
  };

  bmrsa = builderDefsPackage (import ../tools/security/bmrsa/11.nix) {
    inherit unzip;
  };

  bogofilter = callPackage ../tools/misc/bogofilter { };

  bsdiff = callPackage ../tools/compression/bsdiff { };

  btar = callPackage ../tools/backup/btar { };

  bud = callPackage ../tools/networking/bud {
    inherit (pythonPackages) gyp;
  };

  bup = callPackage ../tools/backup/bup {
    inherit (pythonPackages) pyxattr pylibacl setuptools fuse;
    inherit (haskellPackages) pandoc;
    par2Support = (config.bup.par2Support or false);
  };

  byzanz = callPackage ../applications/video/byzanz {};

  ori = callPackage ../tools/backup/ori { };

  atool = callPackage ../tools/archivers/atool { };

  bzip2 = callPackage ../tools/compression/bzip2 { };

  cabextract = callPackage ../tools/archivers/cabextract { };

  cadaver = callPackage ../tools/networking/cadaver { };

  cantata = callPackage ../applications/audio/cantata { };

  can-utils = callPackage ../os-specific/linux/can-utils { };

  caudec = callPackage ../applications/audio/caudec { };

  ccid = callPackage ../tools/security/ccid { };

  ccrypt = callPackage ../tools/security/ccrypt { };

  cdecl = callPackage ../development/tools/cdecl { };

  cdrdao = callPackage ../tools/cd-dvd/cdrdao { };

  cdrkit = callPackage ../tools/cd-dvd/cdrkit { };

  ceph = callPackage ../tools/filesystems/ceph {
    zfs = linuxPackages.zfs;
  };

  cfdg = builderDefsPackage ../tools/graphics/cfdg {
    inherit libpng bison flex ffmpeg;
  };

  checkinstall = callPackage ../tools/package-management/checkinstall { };

  cheetahTemplate = builderDefsPackage (import ../tools/text/cheetah-template/2.0.1.nix) {
    inherit makeWrapper python;
  };

  chkrootkit = callPackage ../tools/security/chkrootkit { };

  chocolateDoom = callPackage ../games/chocolate-doom { };

  chrony = callPackage ../tools/networking/chrony { };

  chunkfs = callPackage ../tools/filesystems/chunkfs { };

  chunksync = callPackage ../tools/backup/chunksync { };

  cjdns = callPackage ../tools/networking/cjdns { };

  cksfv = callPackage ../tools/networking/cksfv { };

  clementine = callPackage ../applications/audio/clementine { };

  ciopfs = callPackage ../tools/filesystems/ciopfs { };

  cmst = callPackage ../tools/networking/cmst { };

  colord = callPackage ../tools/misc/colord { };

  colord-gtk = callPackage ../tools/misc/colord-gtk { };

  colordiff = callPackage ../tools/text/colordiff { };

  concurrencykit = callPackage ../development/libraries/concurrencykit { };

  connect = callPackage ../tools/networking/connect { };

  conspy = callPackage ../os-specific/linux/conspy {};

  connman = callPackage ../tools/networking/connman { };

  connmanui = callPackage ../tools/networking/connmanui { };

  convertlit = callPackage ../tools/text/convertlit { };

  collectd = callPackage ../tools/system/collectd { };

  colormake = callPackage ../development/tools/build-managers/colormake { };

  cowsay = callPackage ../tools/misc/cowsay { };

  cpuminer = callPackage ../tools/misc/cpuminer { };

  cpuminer-multi = callPackage ../tools/misc/cpuminer-multi { };

  cuetools = callPackage ../tools/cd-dvd/cuetools { };

  unifdef = callPackage ../development/tools/misc/unifdef { };

  "unionfs-fuse" = callPackage ../tools/filesystems/unionfs-fuse { };

  usb_modeswitch = callPackage ../development/tools/misc/usb-modeswitch { };

  anthy = callPackage ../tools/inputmethods/anthy { };

  biosdevname = callPackage ../tools/networking/biosdevname { };

  clamav = callPackage ../tools/security/clamav { };

  cloc = callPackage ../tools/misc/cloc {
    inherit (perlPackages) perl AlgorithmDiff RegexpCommon;
  };

  cloog = callPackage ../development/libraries/cloog { };

  cloogppl = callPackage ../development/libraries/cloog-ppl { };

  convmv = callPackage ../tools/misc/convmv { };

  cool-old-term = callPackage ../applications/misc/cool-old-term { };

  coreutils = callPackage ../tools/misc/coreutils
    {
      # TODO: Add ACL support for cross-Linux.
      aclSupport = crossSystem == null && stdenv.isLinux;
    };

  cpio = callPackage ../tools/archivers/cpio { };

  cromfs = callPackage ../tools/archivers/cromfs { };

  cron = callPackage ../tools/system/cron { };

  cudatoolkit5 = callPackage ../development/compilers/cudatoolkit/5.5.nix {
    python = python26;
  };

  cudatoolkit6 = callPackage ../development/compilers/cudatoolkit/6.0.nix {
    python = python26;
  };

  cudatoolkit = cudatoolkit5;

  curl = callPackage ../tools/networking/curl rec {
    fetchurl = fetchurlBoot;
    zlibSupport = true;
    sslSupport = zlibSupport;
    scpSupport = zlibSupport && !stdenv.isSunOS && !stdenv.isCygwin;
  };

  curl3 = callPackage ../tools/networking/curl/7.15.nix rec {
    zlibSupport = true;
    sslSupport = zlibSupport;
  };

  curl_unix_socket = callPackage ../tools/networking/curl-unix-socket rec { };

  cunit = callPackage ../tools/misc/cunit { };

  curlftpfs = callPackage ../tools/filesystems/curlftpfs { };

  cutter = callPackage ../tools/networking/cutter { };

  dadadodo = callPackage ../tools/text/dadadodo { };

  daq = callPackage ../applications/networking/ids/daq { };

  dar = callPackage ../tools/archivers/dar { };

  davfs2 = callPackage ../tools/filesystems/davfs2 { };

  dbench = callPackage ../development/tools/misc/dbench { };

  dcraw = callPackage ../tools/graphics/dcraw { };

  dcfldd = callPackage ../tools/system/dcfldd { };

  debian_devscripts = callPackage ../tools/misc/debian-devscripts {
    inherit (perlPackages) CryptSSLeay LWP TimeDate DBFile FileDesktopEntry;
  };

  debootstrap = callPackage ../tools/misc/debootstrap { };

  detox = callPackage ../tools/misc/detox { };

  ddclient = callPackage ../tools/networking/ddclient { };

  dd_rescue = callPackage ../tools/system/dd_rescue { };

  ddrescue = callPackage ../tools/system/ddrescue { };

  deluge = pythonPackages.deluge;

  desktop_file_utils = callPackage ../tools/misc/desktop-file-utils { };

  despotify = callPackage ../development/libraries/despotify { };

  dfc  = callPackage ../tools/system/dfc { };

  dev86 = callPackage ../development/compilers/dev86 { };

  dnscrypt-proxy = callPackage ../tools/networking/dnscrypt-proxy { };

  dnsmasq = callPackage ../tools/networking/dnsmasq { };

  dnstop = callPackage ../tools/networking/dnstop { };

  dhcp = callPackage ../tools/networking/dhcp { };

  dhcpcd = callPackage ../tools/networking/dhcpcd { };

  di = callPackage ../tools/system/di { };

  diffstat = callPackage ../tools/text/diffstat { };

  diffutils = callPackage ../tools/text/diffutils { };

  wgetpaste = callPackage ../tools/text/wgetpaste { };

  dirmngr = callPackage ../tools/security/dirmngr { };

  disper = callPackage ../tools/misc/disper { };

  dmd = callPackage ../development/compilers/dmd { };

  dmg2img = callPackage ../tools/misc/dmg2img { };

  docbook2odf = callPackage ../tools/typesetting/docbook2odf {
    inherit (perlPackages) PerlMagick;
  };

  docbook2x = callPackage ../tools/typesetting/docbook2x {
    inherit (perlPackages) XMLSAX XMLParser XMLNamespaceSupport;
  };

  dog = callPackage ../tools/system/dog { };

  dosfstools = callPackage ../tools/filesystems/dosfstools { };

  dotnetfx35 = callPackage ../development/libraries/dotnetfx35 { };

  dotnetfx40 = callPackage ../development/libraries/dotnetfx40 { };

  dolphinEmu = callPackage ../misc/emulators/dolphin-emu { };
  dolphinEmuMaster = callPackage ../misc/emulators/dolphin-emu/master.nix { };

  doomseeker = callPackage ../applications/misc/doomseeker { };

  dropbear = callPackage ../tools/networking/dropbear { };

  dtach = callPackage ../tools/misc/dtach { };

  duo-unix = callPackage ../tools/security/duo-unix { };

  duplicity = callPackage ../tools/backup/duplicity {
    inherit (pythonPackages) boto lockfile;
    gnupg = gnupg1;
  };

  duply = callPackage ../tools/backup/duply { };

  dvdisaster = callPackage ../tools/cd-dvd/dvdisaster { };

  dvdplusrwtools = callPackage ../tools/cd-dvd/dvd+rw-tools { };

  dvgrab = callPackage ../tools/video/dvgrab { };

  dvtm = callPackage ../tools/misc/dvtm { };

  e2fsprogs = callPackage ../tools/filesystems/e2fsprogs { };

  easyrsa = callPackage ../tools/networking/easyrsa { };

  ebook_tools = callPackage ../tools/text/ebook-tools { };

  ecryptfs = callPackage ../tools/security/ecryptfs { };

  editres = callPackage ../tools/graphics/editres {
    inherit (xlibs) libXt libXaw;
    inherit (xorg) utilmacros;
  };

  edk2 = callPackage ../development/compilers/edk2 { };

  eid-viewer = callPackage ../tools/security/eid-viewer { };

  emscripten = callPackage ../development/compilers/emscripten { };

  emscriptenfastcomp = callPackage ../development/compilers/emscripten-fastcomp { };

  efibootmgr = callPackage ../tools/system/efibootmgr { };

  efivar = callPackage ../tools/system/efivar { };

  evemu = callPackage ../tools/system/evemu { };

  elasticsearch = callPackage ../servers/search/elasticsearch { };

  elasticsearchPlugins = recurseIntoAttrs (
    callPackage ../servers/search/elasticsearch/plugins.nix { }
  );

  emv = callPackage ../tools/misc/emv { };

  enblendenfuse = callPackage ../tools/graphics/enblend-enfuse { };

  encfs = callPackage ../tools/filesystems/encfs { };

  enscript = callPackage ../tools/text/enscript { };

  ethtool = callPackage ../tools/misc/ethtool { };

  eternity = callPackage ../games/eternity-engine { };

  ettercap = callPackage ../applications/networking/sniffers/ettercap { };

  euca2ools = callPackage ../tools/virtualization/euca2ools { pythonPackages = python26Packages; };

  evtest = callPackage ../applications/misc/evtest { };

  exempi = callPackage ../development/libraries/exempi { boost = boost155; };

  execline = callPackage ../tools/misc/execline { };

  exercism = callPackage ../development/tools/exercism { };

  exif = callPackage ../tools/graphics/exif { };

  exiftags = callPackage ../tools/graphics/exiftags { };

  extundelete = callPackage ../tools/filesystems/extundelete { };

  expect = callPackage ../tools/misc/expect { };

  f2fs-tools = callPackage ../tools/filesystems/f2fs-tools { };

  fabric = pythonPackages.fabric;

  fail2ban = callPackage ../tools/security/fail2ban {
    systemd = systemd.override {
      pythonSupport = true;
    };
  };

  fakeroot = callPackage ../tools/system/fakeroot { };

  fakechroot = callPackage ../tools/system/fakechroot { };

  fatrace = callPackage ../os-specific/linux/fatrace { };

  fcitx = callPackage ../tools/inputmethods/fcitx { };

  fcitx-anthy = callPackage ../tools/inputmethods/fcitx/fcitx-anthy.nix { };

  fcitx-configtool = callPackage ../tools/inputmethods/fcitx/fcitx-configtool.nix { };

  fcitx-with-plugins = callPackage ../tools/inputmethods/fcitx/wrapper.nix {
    plugins = [ ];
  };

  fcron = callPackage ../tools/system/fcron { };

  fdm = callPackage ../tools/networking/fdm {};

  flannel = callPackage ../tools/networking/flannel { };

  figlet = callPackage ../tools/misc/figlet { };

  file = callPackage ../tools/misc/file { };

  filegive = callPackage ../tools/networking/filegive { };

  fileschanged = callPackage ../tools/misc/fileschanged { };

  findutils = callPackage ../tools/misc/findutils { };

  finger_bsd = callPackage ../tools/networking/bsd-finger { };

  fio = callPackage ../tools/system/fio { };

  flashtool = callPackage_i686 ../development/mobile/flashtool {
    platformTools = androidenv.platformTools;
  };

  flashrom = callPackage ../tools/misc/flashrom { };

  flpsed = callPackage ../applications/editors/flpsed { };

  flvstreamer = callPackage ../tools/networking/flvstreamer { };

  libbsd = callPackage ../development/libraries/libbsd { };

  lprof = callPackage ../tools/graphics/lprof { };

  fdk_aac = callPackage ../development/libraries/fdk-aac { };

  flvtool2 = callPackage ../tools/video/flvtool2 { };

  fontforge = lowPrio (callPackage ../tools/misc/fontforge { });

  fontforgeX = callPackage ../tools/misc/fontforge {
    withX11 = true;
  };

  forktty = callPackage ../os-specific/linux/forktty {};

  fortune = callPackage ../tools/misc/fortune { };

  fox = callPackage ../development/libraries/fox/default.nix {
    libpng = libpng12;
  };

  fox_1_6 = callPackage ../development/libraries/fox/fox-1.6.nix { };

  fping = callPackage ../tools/networking/fping {};

  fprot = callPackage ../tools/security/fprot { };

  freeipmi = callPackage ../tools/system/freeipmi {};

  freetalk = callPackage ../applications/networking/instant-messengers/freetalk {
    automake = automake114x;
  };

  freetds = callPackage ../development/libraries/freetds { };

  frescobaldi = callPackage ../misc/frescobaldi {};

  frostwire = callPackage ../applications/networking/p2p/frostwire { };

  ftgl = callPackage ../development/libraries/ftgl { };

  ftgl212 = callPackage ../development/libraries/ftgl/2.1.2.nix { };

  fuppes = callPackage ../tools/networking/fuppes {
    ffmpeg = ffmpeg_0_6_90;
  };

  fsfs = callPackage ../tools/filesystems/fsfs { };

  fuse_zip = callPackage ../tools/filesystems/fuse-zip { };

  fuse_exfat = callPackage ../tools/filesystems/fuse-exfat { };

  dos2unix = callPackage ../tools/text/dos2unix { };

  uni2ascii = callPackage ../tools/text/uni2ascii { };

  g500-control = callPackage ../tools/misc/g500-control { };

  galculator = callPackage ../applications/misc/galculator {
    gtk = gtk3;
  };

  gawk = callPackage ../tools/text/gawk { };

  gawkInteractive = appendToName "interactive"
    (gawk.override { readlineSupport = true; });

  gbdfed = callPackage ../tools/misc/gbdfed {
    gtk = gtk2;
  };

  gdmap = callPackage ../tools/system/gdmap { };

  genext2fs = callPackage ../tools/filesystems/genext2fs { };

  gengetopt = callPackage ../development/tools/misc/gengetopt { };

  getmail = callPackage ../tools/networking/getmail { };

  getopt = callPackage ../tools/misc/getopt { };

  gftp = callPackage ../tools/networking/gftp { };

  gifsicle = callPackage ../tools/graphics/gifsicle { };

  glusterfs = callPackage ../tools/filesystems/glusterfs { };

  glmark2 = callPackage ../tools/graphics/glmark2 { };

  glxinfo = callPackage ../tools/graphics/glxinfo { };

  gmvault = callPackage ../tools/networking/gmvault { };

  gnokii = builderDefsPackage (import ../tools/misc/gnokii) {
    inherit intltool perl gettext libusb pkgconfig bluez readline pcsclite
      libical gtk glib;
    inherit (xorg) libXpm;
  };

  gnufdisk = callPackage ../tools/system/fdisk {
    guile = guile_1_8;
  };

  gnugrep = callPackage ../tools/text/gnugrep { };

  gnulib = callPackage ../development/tools/gnulib { };

  gnupatch = callPackage ../tools/text/gnupatch { };

  gnupg1orig = callPackage ../tools/security/gnupg/1.nix { };

  gnupg1compat = callPackage ../tools/security/gnupg/1compat.nix { };

  # use config.packageOverrides if you prefer original gnupg1
  gnupg1 = gnupg1compat;

  gnupg20 = callPackage ../tools/security/gnupg/20.nix {
    libgcrypt = libgcrypt_1_6;
  };

  gnupg21 = callPackage ../tools/security/gnupg/21.nix {
    libgcrypt = libgcrypt_1_6;
  };

  gnupg = gnupg20;

  gnuplot = callPackage ../tools/graphics/gnuplot { };

  gnuplot_qt = gnuplot.override { withQt = true; };

  # must have AquaTerm installed separately
  gnuplot_aquaterm = gnuplot.override { aquaterm = true; };

  gnused = callPackage ../tools/text/gnused { };

  gnutar = callPackage ../tools/archivers/gnutar { };

  gnuvd = callPackage ../tools/misc/gnuvd { };

  goaccess = callPackage ../tools/misc/goaccess { };

  googleAuthenticator = callPackage ../os-specific/linux/google-authenticator { };

  gource = callPackage ../applications/version-management/gource { };

  gparted = callPackage ../tools/misc/gparted { };

  gpodder = callPackage ../applications/audio/gpodder { };

  gptfdisk = callPackage ../tools/system/gptfdisk { };

  grafana = callPackage ../development/tools/misc/grafana { };

  grafx2 = callPackage ../applications/graphics/grafx2 {};

  grails = callPackage ../development/web/grails {
    jdkPath = "${openjdk}/lib/openjdk";
  };

  graphviz = callPackage ../tools/graphics/graphviz { };

  /* Readded by Michael Raskin. There are programs in the wild
   * that do want 2.0 but not 2.22. Please give a day's notice for
   * objections before removal. The feature is integer coordinates
   */
  graphviz_2_0 = callPackage ../tools/graphics/graphviz/2.0.nix { };

  /* Readded by Michael Raskin. There are programs in the wild
   * that do want 2.32 but not 2.0 or 2.36. Please give a day's notice for
   * objections before removal. The feature is libgraph.
   */
  graphviz_2_32 = callPackage ../tools/graphics/graphviz/2.32.nix { };

  grive = callPackage ../tools/filesystems/grive {
    json_c = json-c-0-11; # won't configure with 0.12; others are vulnerable
  };

  groff = callPackage ../tools/text/groff {
    ghostscript = null;
  };

  grub = callPackage_i686 ../tools/misc/grub {
    buggyBiosCDSupport = config.grub.buggyBiosCDSupport or true;
  };

  trustedGrub = callPackage_i686 ../tools/misc/grub/trusted.nix {
    buggyBiosCDSupport = config.grub.buggyBiosCDSupport or true;
  };

  grub2 = callPackage ../tools/misc/grub/2.0x.nix { };

  grub2_efi = grub2.override { efiSupport = true; };

  grub2_zfs = grub2.override { zfsSupport = true; };

  gsmartcontrol = callPackage ../tools/misc/gsmartcontrol {
    inherit (gnome) libglademm;
  };

  gssdp = callPackage ../development/libraries/gssdp {
    inherit (gnome) libsoup;
  };

  gt5 = callPackage ../tools/system/gt5 { };

  gtest = callPackage ../development/libraries/gtest {};
  gmock = callPackage ../development/libraries/gmock {};

  gtkdatabox = callPackage ../development/libraries/gtkdatabox {};

  gtkgnutella = callPackage ../tools/networking/p2p/gtk-gnutella { };

  gtkvnc = callPackage ../tools/admin/gtk-vnc {};

  gtmess = callPackage ../applications/networking/instant-messengers/gtmess { };

  gummiboot = callPackage ../tools/misc/gummiboot { };

  gupnp = callPackage ../development/libraries/gupnp {
    inherit (gnome) libsoup;
  };

  gupnp_av = callPackage ../development/libraries/gupnp-av {};

  gupnp_igd = callPackage ../development/libraries/gupnp-igd {};

  gupnptools = callPackage ../tools/networking/gupnp-tools {};

  gvpe = builderDefsPackage ../tools/networking/gvpe {
    inherit openssl gmp nettools iproute zlib;
  };

  gvolicon = callPackage ../tools/audio/gvolicon {};

  gzip = callPackage ../tools/compression/gzip { };

  gzrt = callPackage ../tools/compression/gzrt { };

  partclone = callPackage ../tools/backup/partclone { };

  partimage = callPackage ../tools/backup/partimage { };

  pigz = callPackage ../tools/compression/pigz { };

  pxz = callPackage ../tools/compression/pxz { };

  haproxy = callPackage ../tools/networking/haproxy { };

  haveged = callPackage ../tools/security/haveged { };

  hawkthorne = callPackage ../games/hawkthorne { love = love_0_9; };

  hardlink = callPackage ../tools/system/hardlink { };

  hashcat = callPackage ../tools/security/hashcat { };

  halibut = callPackage ../tools/typesetting/halibut { };

  hddtemp = callPackage ../tools/misc/hddtemp { };

  hdf5 = callPackage ../tools/misc/hdf5 {
    szip = null;
    mpi = null;
  };

  hdf5-mpi = hdf5.override {
    szip = null;
    mpi = pkgs.openmpi;
  };

  heimdall = callPackage ../tools/misc/heimdall { };

  hevea = callPackage ../tools/typesetting/hevea { };

  highlight = callPackage ../tools/text/highlight {
    lua = lua5;
  };

  host = callPackage ../tools/networking/host { };

  hping = callPackage ../tools/networking/hping { };

  httpie = callPackage ../tools/networking/httpie { };

  httpfs2 = callPackage ../tools/filesystems/httpfs { };

  httptunnel = callPackage ../tools/networking/httptunnel { };

  i2pd = callPackage ../tools/networking/i2pd {};

  iasl = callPackage ../development/compilers/iasl { };

  icecast = callPackage ../servers/icecast { };

  icoutils = callPackage ../tools/graphics/icoutils { };

  idutils = callPackage ../tools/misc/idutils { };

  idle3tools = callPackage ../tools/system/idle3tools { };

  iftop = callPackage ../tools/networking/iftop { };

  ifuse = callPackage ../tools/filesystems/ifuse/default.nix { };

  ihaskell = callPackage ../development/tools/haskell/ihaskell/wrapper.nix {
    inherit (pythonPackages) ipython;
    inherit (haskellPackages) ihaskell ghc;
  };

  imapproxy = callPackage ../tools/networking/imapproxy { };

  imapsync = callPackage ../tools/networking/imapsync {
    inherit (perlPackages) MailIMAPClient;
  };

  inadyn = callPackage ../tools/networking/inadyn { };

  inetutils = callPackage ../tools/networking/inetutils { };

  ioping = callPackage ../tools/system/ioping {};

  iodine = callPackage ../tools/networking/iodine { };

  iperf2 = callPackage ../tools/networking/iperf/2.nix { };
  iperf3 = callPackage ../tools/networking/iperf/3.nix { };
  iperf = iperf3;

  ipmitool = callPackage ../tools/system/ipmitool {
    static = false;
  };

  ipmiutil = callPackage ../tools/system/ipmiutil {};

  ised = callPackage ../tools/misc/ised {};

  isl = callPackage ../development/libraries/isl { };
  isl_0_12 = callPackage ../development/libraries/isl/0.12.2.nix { };

  isync = callPackage ../tools/networking/isync { };

  jd-gui = callPackage_i686 ../tools/security/jd-gui { };

  jdiskreport = callPackage ../tools/misc/jdiskreport { };

  jfsutils = callPackage ../tools/filesystems/jfsutils { };

  jhead = callPackage ../tools/graphics/jhead { };

  jing = callPackage ../tools/text/xml/jing { };

  jmtpfs = callPackage ../tools/filesystems/jmtpfs { };

  jnettop = callPackage ../tools/networking/jnettop { };

  john = callPackage ../tools/security/john { };

  jq = callPackage ../development/tools/jq {};

  jscoverage = callPackage ../development/tools/misc/jscoverage { };

  jwhois = callPackage ../tools/networking/jwhois { };

  k2pdfopt = callPackage ../applications/misc/k2pdfopt { };

  kazam = callPackage ../applications/video/kazam { };

  kalibrate-rtl = callPackage ../tools/misc/kalibrate-rtl { };

  kexectools = callPackage ../os-specific/linux/kexectools { };

  keybase-node-client = callPackage ../applications/misc/keybase-node-client { };

  keychain = callPackage ../tools/misc/keychain { };

  kibana = callPackage ../development/tools/misc/kibana { };

  kismet = callPackage ../applications/networking/sniffers/kismet { };

  kst = callPackage ../tools/graphics/kst { };

  less = callPackage ../tools/misc/less { };

  liquidsoap = callPackage ../tools/audio/liquidsoap/full.nix { };

  lockfileProgs = callPackage ../tools/misc/lockfile-progs { };

  logstash = callPackage ../tools/misc/logstash { };

  logstash-contrib = callPackage ../tools/misc/logstash/contrib.nix { };

  logstash-forwarder = callPackage ../tools/misc/logstash-forwarder { };

  kippo = callPackage ../servers/kippo { };

  klavaro = callPackage ../games/klavaro {};

  kzipmix = callPackage_i686 ../tools/compression/kzipmix { };

  minidlna = callPackage ../tools/networking/minidlna {
    ffmpeg = ffmpeg_0_10;
  };

  mmv = callPackage ../tools/misc/mmv { };

  morituri = callPackage ../applications/audio/morituri { };

  most = callPackage ../tools/misc/most { };

  multitail = callPackage ../tools/misc/multitail { };

  netperf = callPackage ../applications/networking/netperf { };

  ninka = callPackage ../development/tools/misc/ninka { };

  nodejs = callPackage ../development/web/nodejs { };
  nodejs-unstable = callPackage ../development/web/nodejs { unstableVersion = true; };

  nodePackages = recurseIntoAttrs (import ./node-packages.nix {
    inherit pkgs stdenv nodejs fetchurl fetchgit;
    neededNatives = [python] ++ lib.optional (lib.elem system lib.platforms.linux) utillinux;
    self = pkgs.nodePackages;
  });

  ldapvi = callPackage ../tools/misc/ldapvi { };

  ldns = callPackage ../development/libraries/ldns { };

  leafpad = callPackage ../applications/editors/leafpad { };

  lftp = callPackage ../tools/networking/lftp { };

  libconfig = callPackage ../development/libraries/libconfig { };

  libee = callPackage ../development/libraries/libee { };

  libestr = callPackage ../development/libraries/libestr { };

  libevdev = callPackage ../development/libraries/libevdev { };

  liboauth = callPackage ../development/libraries/liboauth { };

  libtirpc = callPackage ../development/libraries/ti-rpc { };

  libshout = callPackage ../development/libraries/libshout { };

  libqb = callPackage ../development/libraries/libqb { };

  libqmi = callPackage ../development/libraries/libqmi { };

  libmbim = callPackage ../development/libraries/libmbim { };

  libtorrent = callPackage ../tools/networking/p2p/libtorrent { };

  libtorrent-git = callPackage ../tools/networking/p2p/libtorrent/git.nix { };

  libiberty = callPackage ../development/libraries/libiberty { };

  libibverbs = callPackage ../development/libraries/libibverbs { };

  librdmacm = callPackage ../development/libraries/librdmacm { };

  logcheck = callPackage ../tools/system/logcheck {
    inherit (perlPackages) mimeConstruct;
  };

  logkeys = callPackage ../tools/security/logkeys { };

  logrotate = callPackage ../tools/system/logrotate { };

  logstalgia = callPackage ../tools/graphics/logstalgia {};

  lout = callPackage ../tools/typesetting/lout { };

  lrzip = callPackage ../tools/compression/lrzip { };

  # lsh installs `bin/nettle-lfib-stream' and so does Nettle.  Give the
  # former a lower priority than Nettle.
  lsh = lowPrio (callPackage ../tools/networking/lsh { });

  lshw = callPackage ../tools/system/lshw { };

  lxc = callPackage ../os-specific/linux/lxc { };

  lzip = callPackage ../tools/compression/lzip { };

  lzma = xz;

  xz = callPackage ../tools/compression/xz { };

  lzop = callPackage ../tools/compression/lzop { };

  macchanger = callPackage ../os-specific/linux/macchanger { };

  maildrop = callPackage ../tools/networking/maildrop { };

  mailsend = callPackage ../tools/networking/mailsend { };

  mailpile = callPackage ../applications/networking/mailreaders/mailpile { };

  mailutils = callPackage ../tools/networking/mailutils {
    guile = guile_1_8;
  };

  mairix = callPackage ../tools/text/mairix { };

  makemkv = callPackage ../applications/video/makemkv { };

  man = callPackage ../tools/misc/man { };

  man_db = callPackage ../tools/misc/man-db { };

  mbox = callPackage ../tools/security/mbox { };

  memtest86 = callPackage ../tools/misc/memtest86 { };

  memtest86plus = callPackage ../tools/misc/memtest86+ { };

  meo = callPackage ../tools/security/meo {
    boost = boost155;
  };

  mc = callPackage ../tools/misc/mc { };

  mcabber = callPackage ../applications/networking/instant-messengers/mcabber { };

  mcron = callPackage ../tools/system/mcron {
    guile = guile_1_8;
  };

  mdbtools = callPackage ../tools/misc/mdbtools { };

  mdbtools_git = callPackage ../tools/misc/mdbtools/git.nix {
    inherit (gnome) scrollkeeper;
  };

  mednafen = callPackage ../misc/emulators/mednafen { };

  mednafen-server = callPackage ../misc/emulators/mednafen/server.nix { };

  megacli = callPackage ../tools/misc/megacli { };

  megatools = callPackage ../tools/networking/megatools { };

  mfcuk = callPackage ../tools/security/mfcuk { };

  mfoc = callPackage ../tools/security/mfoc { };

  minecraft = callPackage ../games/minecraft {
    pulseaudioSupport = config.pulseaudio or true;
    pulseaudio = pulseaudio.override { ossWrapper = true; };
  };

  minecraft-server = callPackage ../games/minecraft-server { };

  minetest = callPackage ../games/minetest {
    libpng = libpng12;
  };

  miniupnpc = callPackage ../tools/networking/miniupnpc { };

  miniupnpd = callPackage ../tools/networking/miniupnpd { };

  minixml = callPackage ../development/libraries/minixml { };

  mjpegtools = callPackage ../tools/video/mjpegtools { };

  mkcue = callPackage ../tools/cd-dvd/mkcue { };

  mkpasswd = callPackage ../tools/security/mkpasswd { };

  mkrand = callPackage ../tools/security/mkrand { };

  mktemp = callPackage ../tools/security/mktemp { };

  mktorrent = callPackage ../tools/misc/mktorrent { };

  modemmanager = callPackage ../tools/networking/modemmanager {};

  monit = callPackage ../tools/system/monit { };

  mosh = callPackage ../tools/networking/mosh {
    inherit (perlPackages) IOTty;
  };

  mpage = callPackage ../tools/text/mpage { };

  mr = callPackage ../applications/version-management/mr { };

  mscgen = callPackage ../tools/graphics/mscgen { };

  msf = builderDefsPackage (import ../tools/security/metasploit/3.1.nix) {
    inherit ruby makeWrapper;
  };

  mssys = callPackage ../tools/misc/mssys { };

  mtdutils = callPackage ../tools/filesystems/mtdutils { };

  mtools = callPackage ../tools/filesystems/mtools { };

  mtr = callPackage ../tools/networking/mtr {};

  multitran = recurseIntoAttrs (let callPackage = newScope pkgs.multitran; in rec {
    multitrandata = callPackage ../tools/text/multitran/data { };

    libbtree = callPackage ../tools/text/multitran/libbtree { };

    libmtsupport = callPackage ../tools/text/multitran/libmtsupport { };

    libfacet = callPackage ../tools/text/multitran/libfacet { };

    libmtquery = callPackage ../tools/text/multitran/libmtquery { };

    mtutils = callPackage ../tools/text/multitran/mtutils { };
  });

  munge = callPackage ../tools/security/munge { };

  muscleframework = callPackage ../tools/security/muscleframework { };

  muscletool = callPackage ../tools/security/muscletool { };

  mysql2pgsql = callPackage ../tools/misc/mysql2pgsql { };

  namazu = callPackage ../tools/text/namazu { };

  nbd = callPackage ../tools/networking/nbd { };

  ndjbdns = callPackage ../tools/networking/ndjbdns { };

  netatalk = callPackage ../tools/filesystems/netatalk { };

  netcdf = callPackage ../development/libraries/netcdf { };

  nc6 = callPackage ../tools/networking/nc6 { };

  ncat = callPackage ../tools/networking/ncat { };

  ncftp = callPackage ../tools/networking/ncftp { };

  ncompress = callPackage ../tools/compression/ncompress { };

  ndisc6 = callPackage ../tools/networking/ndisc6 { };

  netboot = callPackage ../tools/networking/netboot {};

  netcat = callPackage ../tools/networking/netcat { };

  netcat-openbsd = callPackage ../tools/networking/netcat-openbsd { };

  nethogs = callPackage ../tools/networking/nethogs { };

  netkittftp = callPackage ../tools/networking/netkit/tftp { };

  netpbm = callPackage ../tools/graphics/netpbm { };

  netrw = callPackage ../tools/networking/netrw { };

  netselect = callPackage ../tools/networking/netselect { };

  networkmanager = callPackage ../tools/networking/network-manager { };

  networkmanager_openvpn = callPackage ../tools/networking/network-manager/openvpn.nix { };

  networkmanager_pptp = callPackage ../tools/networking/network-manager/pptp.nix { };

  networkmanager_vpnc = callPackage ../tools/networking/network-manager/vpnc.nix { };

  networkmanager_openconnect = callPackage ../tools/networking/network-manager/openconnect.nix { };

  networkmanagerapplet = newScope gnome ../tools/networking/network-manager-applet { dconf = gnome3.dconf; };

  newsbeuter = callPackage ../applications/networking/feedreaders/newsbeuter { };

  newsbeuter-dev = callPackage ../applications/networking/feedreaders/newsbeuter/dev.nix { };

  ngrep = callPackage ../tools/networking/ngrep { };

  ngrok = callPackage ../tools/misc/ngrok { };

  mpack = callPackage ../tools/networking/mpack { };

  pa_applet = callPackage ../tools/audio/pa-applet { };

  pasystray = callPackage ../tools/audio/pasystray {
    inherit (gnome3) gnome_icon_theme;
  };

  pnmixer = callPackage ../tools/audio/pnmixer { };

  nifskope = callPackage ../tools/graphics/nifskope { };

  nilfs-utils = callPackage ../tools/filesystems/nilfs-utils {};
  nilfs_utils = nilfs-utils;

  nitrogen = callPackage ../tools/X11/nitrogen {};

  nlopt = callPackage ../development/libraries/nlopt {};

  npapi_sdk = callPackage ../development/libraries/npapi-sdk {};

  npth = callPackage ../development/libraries/npth {};

  nmap = callPackage ../tools/security/nmap { };

  nmap_graphical = callPackage ../tools/security/nmap {
    inherit (pythonPackages) pysqlite;
    graphicalSupport = true;
  };

  notbit = callPackage ../applications/networking/notbit { };

  notify-osd = callPackage ../applications/misc/notify-osd { };

  nox = callPackage ../tools/package-management/nox {
    pythonPackages = python3Packages;
    nix = nixUnstable;
  };

  nss_pam_ldapd = callPackage ../tools/networking/nss-pam-ldapd {};

  ntfs3g = callPackage ../tools/filesystems/ntfs-3g { };

  # ntfsprogs are merged into ntfs-3g
  ntfsprogs = pkgs.ntfs3g;

  ntop = callPackage ../tools/networking/ntop { };

  ntopng = callPackage ../tools/networking/ntopng { };

  ntp = callPackage ../tools/networking/ntp { };

  numdiff = callPackage ../tools/text/numdiff { };

  nssmdns = callPackage ../tools/networking/nss-mdns { };

  nwdiag = pythonPackages.nwdiag;

  nylon = callPackage ../tools/networking/nylon { };

  nzbget = callPackage ../tools/networking/nzbget { };

  oathToolkit = callPackage ../tools/security/oath-toolkit { };

  obex_data_server = callPackage ../tools/bluetooth/obex-data-server { };

  obexd = callPackage ../tools/bluetooth/obexd { };

  obexfs = callPackage ../tools/bluetooth/obexfs { };

  obexftp = callPackage ../tools/bluetooth/obexftp { };

  obnam = callPackage ../tools/backup/obnam { };

  odt2txt = callPackage ../tools/text/odt2txt { };

  odamex = callPackage ../games/odamex { };

  offlineimap = callPackage ../tools/networking/offlineimap {
    inherit (pythonPackages) sqlite3;
  };

  opencryptoki = callPackage ../tools/security/opencryptoki { };

  onscripter-en = callPackage ../games/onscripter-en { };

  opendbx = callPackage ../development/libraries/opendbx { };

  opendkim = callPackage ../development/libraries/opendkim { };

  opendylan = callPackage ../development/compilers/opendylan {
    opendylan-bootstrap = opendylan_bin;
  };

  opendylan_bin = callPackage ../development/compilers/opendylan/bin.nix { };

  openjade = callPackage ../tools/text/sgml/openjade { };

  openntpd = callPackage ../tools/networking/openntpd { };

  openobex = callPackage ../tools/bluetooth/openobex { };

  openopc = callPackage ../tools/misc/openopc {
    pythonFull = python27.buildEnv.override {
      extraLibs = [ python27Packages.pyro3 ];
    };
  };

  openresolv = callPackage ../tools/networking/openresolv { };

  opensc = callPackage ../tools/security/opensc { };

  opensc_dnie_wrapper = callPackage ../tools/security/opensc-dnie-wrapper { };

  openssh =
    callPackage ../tools/networking/openssh {
      hpnSupport = false;
      withKerberos = false;
      etcDir = "/etc/ssh";
      pam = if stdenv.isLinux then pam else null;
    };

  openssh_hpn = pkgs.appendToName "with-hpn" (openssh.override { hpnSupport = true; });

  openssh_with_kerberos = pkgs.appendToName "with-kerberos" (openssh.override { withKerberos = true; });

  opensp = callPackage ../tools/text/sgml/opensp {
    stdenv = if stdenv.isDarwin
      then allStdenvs.stdenvDarwinNaked
      else stdenv;
  };

  spCompat = callPackage ../tools/text/sgml/opensp/compat.nix { };

  opentracker = callPackage ../applications/networking/p2p/opentracker { };

  openvpn = callPackage ../tools/networking/openvpn { };

  openvpn_learnaddress = callPackage ../tools/networking/openvpn/openvpn_learnaddress.nix { };

  update-resolv-conf = callPackage ../tools/networking/openvpn/update-resolv-conf.nix { };

  openvswitch = callPackage ../os-specific/linux/openvswitch { };

  optipng = callPackage ../tools/graphics/optipng {
    libpng = libpng12;
  };

  oslrd = callPackage ../tools/networking/oslrd { };

  ossec = callPackage ../tools/security/ossec {};

  ostree = callPackage ../tools/misc/ostree { };

  otpw = callPackage ../os-specific/linux/otpw { };

  owncloudclient = callPackage ../applications/networking/owncloud-client { };

  p7zip = callPackage ../tools/archivers/p7zip { };

  pal = callPackage ../tools/misc/pal { };

  panomatic = callPackage ../tools/graphics/panomatic { };

  par2cmdline = callPackage ../tools/networking/par2cmdline { };

  parallel = callPackage ../tools/misc/parallel { };

  parcellite = callPackage ../tools/misc/parcellite { };

  patchutils = callPackage ../tools/text/patchutils { };

  parted = callPackage ../tools/misc/parted { hurd = null; };

  pitivi = callPackage ../applications/video/pitivi {
    gst = gst_all_1;
    clutter-gtk = clutter_gtk;
    inherit (gnome3) gnome_icon_theme gnome_icon_theme_symbolic;
  };

  p0f = callPackage ../tools/security/p0f { };

  pngout = callPackage ../tools/graphics/pngout { };

  hurdPartedCross =
    if crossSystem != null && crossSystem.config == "i586-pc-gnu"
    then (makeOverridable
            ({ hurd }:
              (parted.override {
                # Needs the Hurd's libstore.
                inherit hurd;

                # The Hurd wants a libparted.a.
                enableStatic = true;

                gettext = null;
                readline = null;
                devicemapper = null;
              }).crossDrv)
           { hurd = gnu.hurdCrossIntermediate; })
    else null;

  ipsecTools = callPackage ../os-specific/linux/ipsec-tools { flex = flex_2_5_35; };

  patch = gnupatch;

  pbzip2 = callPackage ../tools/compression/pbzip2 { };

  pciutils = callPackage ../tools/system/pciutils { };

  pcsclite = callPackage ../tools/security/pcsclite { };

  pdf2djvu = callPackage ../tools/typesetting/pdf2djvu { };

  pdf2svg = callPackage ../tools/graphics/pdf2svg { };

  pdfjam = callPackage ../tools/typesetting/pdfjam { };

  jbig2enc = callPackage ../tools/graphics/jbig2enc { };

  pdfread = callPackage ../tools/graphics/pdfread { };

  briss = callPackage ../tools/graphics/briss { };

  brickd = callPackage ../servers/brickd {
    libusb = libusb1;
  };

  bully = callPackage ../tools/networking/bully { };

  pdnsd = callPackage ../tools/networking/pdnsd { };

  peco = callPackage ../tools/text/peco { };

  pg_top = callPackage ../tools/misc/pg_top { };

  pdsh = callPackage ../tools/networking/pdsh {
    rsh = true;          # enable internal rsh implementation
    ssh = openssh;
  };

  pfstools = callPackage ../tools/graphics/pfstools { };

  philter = callPackage ../tools/networking/philter { };

  pinentry = callPackage ../tools/security/pinentry { };

  pius = callPackage ../tools/security/pius { };

  pk2cmd = callPackage ../tools/misc/pk2cmd { };

  plantuml = callPackage ../tools/misc/plantuml { };

  plan9port = callPackage ../tools/system/plan9port { };

  ploticus = callPackage ../tools/graphics/ploticus {
    libpng = libpng12;
  };

  plotutils = callPackage ../tools/graphics/plotutils { };

  plowshare = callPackage ../tools/misc/plowshare { };

  pngcrush = callPackage ../tools/graphics/pngcrush { };

  pngnq = callPackage ../tools/graphics/pngnq { };

  pngtoico = callPackage ../tools/graphics/pngtoico {
    libpng = libpng12;
  };

  pngquant = callPackage ../tools/graphics/pngquant { };

  podiff = callPackage ../tools/text/podiff { };

  poedit = callPackage ../tools/text/poedit { };

  polipo = callPackage ../servers/polipo { };

  polkit_gnome = callPackage ../tools/security/polkit-gnome { };

  ponysay = callPackage ../tools/misc/ponysay { };

  povray = callPackage ../tools/graphics/povray { };

  ppl = callPackage ../development/libraries/ppl { };

  ppp = callPackage ../tools/networking/ppp { };

  pptp = callPackage ../tools/networking/pptp {};

  prey-bash-client = callPackage ../tools/security/prey { };

  projectm = callPackage ../applications/audio/projectm { };

  proot = callPackage ../tools/system/proot { };

  proxychains = callPackage ../tools/networking/proxychains { };

  proxytunnel = callPackage ../tools/misc/proxytunnel { };

  cntlm = callPackage ../tools/networking/cntlm { };

  pastebinit = callPackage ../tools/misc/pastebinit { };

  psmisc = callPackage ../os-specific/linux/psmisc { };

  pstoedit = callPackage ../tools/graphics/pstoedit { };

  pv = callPackage ../tools/misc/pv { };

  pwgen = callPackage ../tools/security/pwgen { };

  pwnat = callPackage ../tools/networking/pwnat { };

  pycangjie = callPackage ../development/python-modules/pycangjie { };

  pydb = callPackage ../development/tools/pydb { };

  pystringtemplate = callPackage ../development/python-modules/stringtemplate { };

  pythonDBus = dbus_python;

  pythonIRClib = builderDefsPackage (import ../development/python-modules/irclib) {
    inherit python;
  };

  pythonSexy = builderDefsPackage (import ../development/python-modules/libsexy) {
    inherit python libsexy pkgconfig libxml2 pygtk pango gtk glib;
  };

  openmpi = callPackage ../development/libraries/openmpi { };

  qhull = callPackage ../development/libraries/qhull { };

  qjoypad = callPackage ../tools/misc/qjoypad { };

  qpdf = callPackage ../development/libraries/qpdf { };

  qscintilla = callPackage ../development/libraries/qscintilla {
    qt = qt4;
  };

  qshowdiff = callPackage ../tools/text/qshowdiff { };

  quilt = callPackage ../development/tools/quilt { };

  radvd = callPackage ../tools/networking/radvd { };

  ranger = callPackage ../applications/misc/ranger { };

  privateer = callPackage ../games/privateer { };

  redmine = callPackage ../applications/version-management/redmine { };

  rtmpdump = callPackage ../tools/video/rtmpdump { };

  reaverwps = callPackage ../tools/networking/reaver-wps {};

  recutils = callPackage ../tools/misc/recutils { };

  recoll = callPackage ../applications/search/recoll { };

  reiser4progs = callPackage ../tools/filesystems/reiser4progs { };

  reiserfsprogs = callPackage ../tools/filesystems/reiserfsprogs { };

  relfs = callPackage ../tools/filesystems/relfs {
    inherit (gnome) gnome_vfs GConf;
  };

  remarkjs = callPackage ../development/web/remarkjs { };

  remind = callPackage ../tools/misc/remind { };

  remmina = callPackage ../applications/networking/remote/remmina {};

  renameutils = callPackage ../tools/misc/renameutils { };

  replace = callPackage ../tools/text/replace { };

  reptyr = callPackage ../os-specific/linux/reptyr {};

  rdiff-backup = callPackage ../tools/backup/rdiff-backup { };

  rdmd = callPackage ../development/compilers/rdmd { };

  rhash = callPackage ../tools/security/rhash { };

  riemann_c_client = callPackage ../tools/misc/riemann-c-client { };

  ripmime = callPackage ../tools/networking/ripmime {};

  rkflashtool = callPackage ../tools/misc/rkflashtool { };

  rmlint = callPackage ../tools/misc/rmlint {};

  rng_tools = callPackage ../tools/security/rng-tools { };

  rsnapshot = callPackage ../tools/backup/rsnapshot {
    # For the `logger' command, we can use either `utillinux' or
    # GNU Inetutils.  The latter is more portable.
    logger = inetutils;
  };
  rsnapshotGit = lowPrio (callPackage ../tools/backup/rsnapshot/git.nix {
    # For the `logger' command, we can use either `utillinux' or
    # GNU Inetutils.  The latter is more portable.
    logger = inetutils;
  });

  rlwrap = callPackage ../tools/misc/rlwrap { };

  rockbox_utility = callPackage ../tools/misc/rockbox-utility { };

  rpPPPoE = builderDefsPackage (import ../tools/networking/rp-pppoe) {
    inherit ppp;
  };

  rpm = callPackage ../tools/package-management/rpm { };

  rpmextract = callPackage ../tools/archivers/rpmextract { };

  rrdtool = callPackage ../tools/misc/rrdtool { };

  rtorrent = callPackage ../tools/networking/p2p/rtorrent { };

  rtorrent-git = callPackage ../tools/networking/p2p/rtorrent/git.nix { };

  rubber = callPackage ../tools/typesetting/rubber { };

  rxp = callPackage ../tools/text/xml/rxp { };

  rzip = callPackage ../tools/compression/rzip { };

  s3backer = callPackage ../tools/filesystems/s3backer { };

  s3cmd = callPackage ../tools/networking/s3cmd { };

  s3cmd_15_pre_81e3842f7a = lowPrio (callPackage ../tools/networking/s3cmd/git.nix { });

  s3sync = callPackage ../tools/networking/s3sync {
    ruby = ruby_1_8;
  };

  s6Dns = callPackage ../tools/networking/s6-dns { };

  s6LinuxUtils = callPackage ../os-specific/linux/s6-linux-utils { };

  s6Networking = callPackage ../tools/networking/s6-networking { };

  s6PortableUtils = callPackage ../tools/misc/s6-portable-utils { };

  sablotron = callPackage ../tools/text/xml/sablotron { };

  safecopy = callPackage ../tools/system/safecopy { };

  safe-rm = callPackage ../tools/system/safe-rm { };

  salut_a_toi = callPackage ../applications/networking/instant-messengers/salut-a-toi {};

  samplicator = callPackage ../tools/networking/samplicator { };

  screen = callPackage ../tools/misc/screen { };

  scrot = callPackage ../tools/graphics/scrot { };

  scrypt = callPackage ../tools/security/scrypt { };

  sdcv = callPackage ../applications/misc/sdcv { };

  sec = callPackage ../tools/admin/sec { };

  seccure = callPackage ../tools/security/seccure { };

  setserial = builderDefsPackage (import ../tools/system/setserial) {
    inherit groff;
  };

  seqdiag = pythonPackages.seqdiag;

  screenfetch = callPackage ../tools/misc/screenfetch { };

  sg3_utils = callPackage ../tools/system/sg3_utils { };

  sharutils = callPackage ../tools/archivers/sharutils { };

  shotwell = callPackage ../applications/graphics/shotwell { };

  shebangfix = callPackage ../tools/misc/shebangfix { };

  shellinabox = callPackage ../servers/shellinabox { };

  siege = callPackage ../tools/networking/siege {};

  sigil = callPackage ../applications/editors/sigil { };

  silc_client = callPackage ../applications/networking/instant-messengers/silc-client { };

  silc_server = callPackage ../servers/silc-server { };

  silver-searcher = callPackage ../tools/text/silver-searcher { };

  simplescreenrecorder = callPackage ../applications/video/simplescreenrecorder { };

  sleuthkit = callPackage ../tools/system/sleuthkit {};

  slimrat = callPackage ../tools/networking/slimrat {
    inherit (perlPackages) WWWMechanize LWP;
  };

  slsnif = callPackage ../tools/misc/slsnif { };

  smartmontools = callPackage ../tools/system/smartmontools { };

  smbldaptools = callPackage ../tools/networking/smbldaptools {
    inherit (perlPackages) NetLDAP CryptSmbHash DigestSHA1;
  };

  smbnetfs = callPackage ../tools/filesystems/smbnetfs {};

  snort = callPackage ../applications/networking/ids/snort { };

  solr = callPackage ../servers/search/solr { };

  solvespace = callPackage ../applications/graphics/solvespace { };

  sparsehash = callPackage ../development/libraries/sparsehash { };

  spiped = callPackage ../tools/networking/spiped { };

  sproxy = haskellPackages.callPackage ../tools/networking/sproxy { };

  sproxy-web = haskellPackages.callPackage ../tools/networking/sproxy-web { };

  sqliteman = callPackage ../applications/misc/sqliteman { };

  stardict = callPackage ../applications/misc/stardict/stardict.nix {
    inherit (gnome) libgnomeui scrollkeeper;
  };

  stdman = callPackage ../data/documentation/stdman { };

  storebrowse = callPackage ../tools/system/storebrowse { };

  fusesmb = callPackage ../tools/filesystems/fusesmb { };

  sl = callPackage ../tools/misc/sl { };

  socat = callPackage ../tools/networking/socat { };

  socat2pre = lowPrio (callPackage ../tools/networking/socat/2.x.nix { });

  sourceHighlight = callPackage ../tools/text/source-highlight { };

  spaceFM = callPackage ../applications/misc/spacefm { };

  squashfsTools = callPackage ../tools/filesystems/squashfs { };

  sshfsFuse = callPackage ../tools/filesystems/sshfs-fuse { };

  sshuttle = callPackage ../tools/security/sshuttle { };

  sudo = callPackage ../tools/security/sudo { };

  suidChroot = builderDefsPackage (import ../tools/system/suid-chroot) { };

  super = callPackage ../tools/security/super { };

  ssdeep = callPackage ../tools/security/ssdeep { };

  sshpass = callPackage ../tools/networking/sshpass { };

  ssmtp = callPackage ../tools/networking/ssmtp {
    tlsSupport = true;
  };

  ssss = callPackage ../tools/security/ssss { };

  storeBackup = callPackage ../tools/backup/store-backup { };

  stow = callPackage ../tools/misc/stow { };

  stun = callPackage ../tools/networking/stun { };

  stunnel = callPackage ../tools/networking/stunnel { };

  strongswan = callPackage ../tools/networking/strongswan { };

  su = shadow.su;

  surfraw = callPackage ../tools/networking/surfraw { };

  swec = callPackage ../tools/networking/swec {
    inherit (perlPackages) LWP URI HTMLParser HTTPServerSimple Parent;
  };

  svnfs = callPackage ../tools/filesystems/svnfs { };

  sysbench = callPackage ../development/tools/misc/sysbench {};

  system_config_printer = callPackage ../tools/misc/system-config-printer {
    libxml2 = libxml2Python;
   };

  sitecopy = callPackage ../tools/networking/sitecopy { };

  stricat = callPackage ../tools/security/stricat { };

  privoxy = callPackage ../tools/networking/privoxy { };

  swaks = callPackage ../tools/networking/swaks { };

  t1utils = callPackage ../tools/misc/t1utils { };

  tarsnap = callPackage ../tools/backup/tarsnap { };

  tcpcrypt = callPackage ../tools/security/tcpcrypt { };

  tboot = callPackage ../tools/security/tboot { };

  tcl2048 = callPackage ../games/tcl2048 { };

  tcpdump = callPackage ../tools/networking/tcpdump { };

  tcpflow = callPackage ../tools/networking/tcpflow { };

  teamviewer = callPackage_i686 ../applications/networking/remote/teamviewer { };

  # Work In Progress: it doesn't start unless running a daemon as root
  teamviewer8 = lowPrio (callPackage_i686 ../applications/networking/remote/teamviewer/8.nix { });

  teamviewer9 = lowPrio (callPackage_i686 ../applications/networking/remote/teamviewer/9.nix { });

  telnet = callPackage ../tools/networking/telnet { };

  tessel = callPackage ../applications/misc/tessel { };

  texmacs = callPackage ../applications/editors/texmacs {
    tex = texLive; /* tetex is also an option */
    extraFonts = true;
    guile = guile_1_8;
  };

  texmaker = callPackage ../applications/editors/texmaker { };

  texstudio = callPackage ../applications/editors/texstudio { };

  thc-hydra = callPackage ../tools/security/thc-hydra { };

  tiled-qt = callPackage ../applications/editors/tiled-qt { qt = qt4; };

  tinc = callPackage ../tools/networking/tinc { };

  tinc_pre = callPackage ../tools/networking/tinc/pre.nix { };

  tiny8086 = callPackage ../applications/virtualization/8086tiny { };

  tmpwatch = callPackage ../tools/misc/tmpwatch  { };

  tmux = callPackage ../tools/misc/tmux { };

  tor = callPackage ../tools/security/tor { };

  torbutton = callPackage ../tools/security/torbutton { };

  torbrowser = callPackage ../tools/security/tor/torbrowser.nix {
    stdenv = overrideGCC stdenv gcc49;
  };

  torsocks = callPackage ../tools/security/tor/torsocks.nix { };

  tpm-quote-tools = callPackage ../tools/security/tpm-quote-tools { };

  tpm-tools = callPackage ../tools/security/tpm-tools { };

  traceroute = callPackage ../tools/networking/traceroute { };

  trickle = callPackage ../tools/networking/trickle {};

  trousers = callPackage ../tools/security/trousers { };

  ttf2pt1 = callPackage ../tools/misc/ttf2pt1 { };

  tty-clock = callPackage ../tools/misc/tty-clock { };

  ttysnoop = callPackage ../os-specific/linux/ttysnoop {};

  twitterBootstrap = callPackage ../development/web/twitter-bootstrap {};

  txt2man = callPackage ../tools/misc/txt2man { };

  ucl = callPackage ../development/libraries/ucl { };

  ucspi-tcp = callPackage ../tools/networking/ucspi-tcp { };

  udftools = callPackage ../tools/filesystems/udftools {};

  udptunnel = callPackage ../tools/networking/udptunnel { };

  ufraw = callPackage ../applications/graphics/ufraw { };

  unetbootin = callPackage ../tools/cd-dvd/unetbootin { };

  unfs3 = callPackage ../servers/unfs3 { };

  unoconv = callPackage ../tools/text/unoconv { };

  upx = callPackage ../tools/compression/upx { };

  urlview = callPackage ../applications/misc/urlview {};

  usbmuxd = callPackage ../tools/misc/usbmuxd {};

  vacuum = callPackage ../applications/networking/instant-messengers/vacuum {};

  volatility = callPackage ../tools/security/volatility { };

  vidalia = callPackage ../tools/security/vidalia { };

  vbetool = builderDefsPackage ../tools/system/vbetool {
    inherit pciutils libx86 zlib;
  };

  vde2 = callPackage ../tools/networking/vde2 { };

  vboot_reference = callPackage ../tools/system/vboot_reference { };

  vcsh = callPackage ../applications/version-management/vcsh { };

  verilog = callPackage ../applications/science/electronics/verilog {};

  vfdecrypt = callPackage ../tools/misc/vfdecrypt { };

  vifm = callPackage ../applications/misc/vifm { };

  viking = callPackage ../applications/misc/viking {
    inherit (gnome) scrollkeeper;
  };

  vnc2flv = callPackage ../tools/video/vnc2flv {};

  vncrec = builderDefsPackage ../tools/video/vncrec {
    inherit (xlibs) imake libX11 xproto gccmakedep libXt
      libXmu libXaw libXext xextproto libSM libICE libXpm
      libXp;
  };

  vobcopy = callPackage ../tools/cd-dvd/vobcopy { };

  vobsub2srt = callPackage ../tools/cd-dvd/vobsub2srt { };

  vorbisgain = callPackage ../tools/misc/vorbisgain { };

  vpnc = callPackage ../tools/networking/vpnc { };

  openconnect = callPackage ../tools/networking/openconnect.nix { };

  vtun = callPackage ../tools/networking/vtun { };

  wal_e = callPackage ../tools/backup/wal-e { };

  watchman = callPackage ../development/tools/watchman { };

  wbox = callPackage ../tools/networking/wbox {};

  welkin = callPackage ../tools/graphics/welkin {};

  testdisk = callPackage ../tools/misc/testdisk { };

  html2text = callPackage ../tools/text/html2text { };

  htmlTidy = callPackage ../tools/text/html-tidy { };

  html-xml-utils = callPackage ../tools/text/xml/html-xml-utils { };

  rcm = callPackage ../tools/misc/rcm {};

  tftp_hpa = callPackage ../tools/networking/tftp-hpa {};

  tigervnc = callPackage ../tools/admin/tigervnc {
    fontDirectories = [ xorg.fontadobe75dpi xorg.fontmiscmisc xorg.fontcursormisc
      xorg.fontbhlucidatypewriter75dpi ];
    inherit (xorg) xorgserver;
    fltk = fltk13;
  };

  tightvnc = callPackage ../tools/admin/tightvnc {
    fontDirectories = [ xorg.fontadobe75dpi xorg.fontmiscmisc xorg.fontcursormisc
      xorg.fontbhlucidatypewriter75dpi ];
  };

  time = callPackage ../tools/misc/time { };

  tkabber = callPackage ../applications/networking/instant-messengers/tkabber { };

  qfsm = callPackage ../applications/science/electronics/qfsm { };

  tkgate = callPackage ../applications/science/electronics/tkgate/1.x.nix {
    inherit (xlibs) libX11 imake xproto gccmakedep;
  };

  # The newer package is low-priority because it segfaults at startup.
  tkgate2 = lowPrio (callPackage ../applications/science/electronics/tkgate/2.x.nix {
    inherit (xlibs) libX11;
  });

  tm = callPackage ../tools/system/tm { };

  trang = callPackage ../tools/text/xml/trang { };

  tre = callPackage ../development/libraries/tre { };

  ts = callPackage ../tools/system/ts { };

  transfig = callPackage ../tools/graphics/transfig {
    libpng = libpng12;
  };

  truecrypt = callPackage ../applications/misc/truecrypt {
    wxGUI = config.truecrypt.wxGUI or true;
  };

  ttmkfdir = callPackage ../tools/misc/ttmkfdir { };

  udunits = callPackage ../development/libraries/udunits { };

  uim = callPackage ../tools/inputmethods/uim {
    inherit (pkgs.kde4) kdelibs;
  };

  uhub = callPackage ../servers/uhub { };

  unclutter = callPackage ../tools/misc/unclutter { };

  unbound = callPackage ../tools/networking/unbound { };

  units = callPackage ../tools/misc/units { };

  unrar = callPackage ../tools/archivers/unrar { };

  xar = callPackage ../tools/compression/xar { };

  xarchive = callPackage ../tools/archivers/xarchive { };

  xarchiver = callPackage ../tools/archivers/xarchiver { };

  xcruiser = callPackage ../applications/misc/xcruiser { };

  unarj = callPackage ../tools/archivers/unarj { };

  unshield = callPackage ../tools/archivers/unshield { };

  unzip = callPackage ../tools/archivers/unzip { };

  unzipNLS = lowPrio (unzip.override { enableNLS = true; });

  uptimed = callPackage ../tools/system/uptimed { };

  urlwatch = callPackage ../tools/networking/urlwatch { };

  varnish = callPackage ../servers/varnish { };

  varnish2 = callPackage ../servers/varnish/2.1.nix { };

  venus = callPackage ../tools/misc/venus {
    python = python27;
  };

  vlan = callPackage ../tools/networking/vlan { };

  volumeicon = callPackage ../tools/audio/volumeicon { };

  wakelan = callPackage ../tools/networking/wakelan { };

  wavemon = callPackage ../tools/networking/wavemon { };

  w3cCSSValidator = callPackage ../tools/misc/w3c-css-validator {
    tomcat = tomcat6;
  };

  wdfs = callPackage ../tools/filesystems/wdfs { };

  wdiff = callPackage ../tools/text/wdiff { };

  webalizer = callPackage ../tools/networking/webalizer { };

  webdruid = builderDefsPackage ../tools/admin/webdruid {
    inherit zlib libpng freetype gd which
      libxml2 geoip;
  };

  weighttp = callPackage ../tools/networking/weighttp { };

  wget = callPackage ../tools/networking/wget {
    inherit (perlPackages) LWP;
  };

  which = callPackage ../tools/system/which { };

  wicd = callPackage ../tools/networking/wicd { };

  wipe = callPackage ../tools/security/wipe { };

  wkhtmltopdf = callPackage ../tools/graphics/wkhtmltopdf {
    overrideDerivation = lib.overrideDerivation;
    inherit (xlibs) libX11 libXext libXrender;
  };

  wv = callPackage ../tools/misc/wv { };

  wv2 = callPackage ../tools/misc/wv2 { };

  x86info = callPackage ../os-specific/linux/x86info { };

  x11_ssh_askpass = callPackage ../tools/networking/x11-ssh-askpass { };

  xbursttools = assert stdenv ? glibc; import ../tools/misc/xburst-tools {
    inherit stdenv fetchgit autoconf automake confuse pkgconfig libusb libusb1;
    # It needs a cross compiler for mipsel to build the firmware it will
    # load into the Ben Nanonote
    gccCross =
      let
        pkgsCross = (import ./all-packages.nix) {
          inherit system;
          inherit bootStdenv noSysDirs gccWithCC gccWithProfiling config;
          # Ben Nanonote system
          crossSystem = {
            config = "mipsel-unknown-linux";
            bigEndian = true;
            arch = "mips";
            float = "soft";
            withTLS = true;
            libc = "uclibc";
            platform = {
              name = "ben_nanonote";
              kernelMajor = "2.6";
              # It's not a bcm47xx processor, but for the headers this should work
              kernelHeadersBaseConfig = "bcm47xx_defconfig";
              kernelArch = "mips";
            };
            gcc = {
              arch = "mips32";
            };
          };
        };
      in
        pkgsCross.gccCrossStageStatic;
  };

  xclip = callPackage ../tools/misc/xclip { };

  xtitle = callPackage ../tools/misc/xtitle { };

  xdelta = callPackage ../tools/compression/xdelta { };

  xdummy = callPackage ../tools/misc/xdummy { };

  xfsprogs = callPackage ../tools/filesystems/xfsprogs { };

  xml2 = callPackage ../tools/text/xml/xml2 { };

  xmlroff = callPackage ../tools/typesetting/xmlroff { };

  xmlstarlet = callPackage ../tools/text/xml/xmlstarlet { };

  xmlto = callPackage ../tools/typesetting/xmlto {
    w3m = w3m.override { graphicsSupport = false; };
  };

  xmltv = callPackage ../tools/misc/xmltv { };

  xmpppy = builderDefsPackage (import ../development/python-modules/xmpppy) {
    inherit python setuptools;
  };

  xorriso = callPackage ../tools/cd-dvd/xorriso { };

  xpf = callPackage ../tools/text/xml/xpf {
    libxml2 = libxml2Python;
  };

  xsel = callPackage ../tools/misc/xsel { };

  xtreemfs = callPackage ../tools/filesystems/xtreemfs {};

  xvfb_run = callPackage ../tools/misc/xvfb-run { inherit (texFunctions) fontsConf; };

  xvkbd = callPackage ../tools/X11/xvkbd {
    inherit (xlibs) libXt libXaw libXtst xextproto libXi libXpm gccmakedep;
  };

  youtube-dl = callPackage ../tools/misc/youtube-dl { };

  zbar = callPackage ../tools/graphics/zbar {
    pygtk = lib.overrideDerivation pygtk (x: {
      gtk = gtk2;
    });
  };

  zdelta = callPackage ../tools/compression/zdelta { };

  zfstools = callPackage ../tools/filesystems/zfstools {
    zfs = linuxPackages.zfs;
  };

  zile = callPackage ../applications/editors/zile { };

  zip = callPackage ../tools/archivers/zip { };

  zpaq = callPackage ../tools/archivers/zpaq { };
  zpaqd = callPackage ../tools/archivers/zpaq/zpaqd.nix { };

  zsync = callPackage ../tools/compression/zsync { };

  zxing = callPackage ../tools/graphics/zxing {};


  ### SHELLS

  bash = lowPrio (callPackage ../shells/bash {
    texinfo = null;
  });

  bashInteractive = appendToName "interactive" (callPackage ../shells/bash {
    interactive = true;
  });

  bashCompletion = callPackage ../shells/bash-completion { };

  dash = callPackage ../shells/dash { };

  fish = callPackage ../shells/fish {
    python = python27Full;
  };

  tcsh = callPackage ../shells/tcsh { };

  rush = callPackage ../shells/rush { };

  zsh = callPackage ../shells/zsh { };


  ### DEVELOPMENT / COMPILERS

  abc =
    abcPatchable [];

  abcPatchable = patches :
    import ../development/compilers/abc/default.nix {
      inherit stdenv fetchurl patches jre apacheAnt;
      javaCup = callPackage ../development/libraries/java/cup { };
    };

  aldor = callPackage ../development/compilers/aldor { };

  aliceml = callPackage ../development/compilers/aliceml { };

  aspectj = callPackage ../development/compilers/aspectj { };

  ats = callPackage ../development/compilers/ats { };
  ats2 = callPackage ../development/compilers/ats2 { };

  avra = callPackage ../development/compilers/avra { };

  bigloo = callPackage ../development/compilers/bigloo { };

  fetchegg = callPackage ../build-support/fetchegg { };

  eggDerivation = callPackage ../development/compilers/chicken/eggDerivation.nix { };

  chicken = callPackage ../development/compilers/chicken {
    bootstrap-chicken = chicken.override { bootstrap-chicken = null; };
  };

  egg2nix = callPackage ../development/tools/egg2nix {
    chickenEggs = callPackage ../development/tools/egg2nix/chicken-eggs.nix { };
  };

  ccl = builderDefsPackage ../development/compilers/ccl {};

  clang = wrapGCC llvmPackages.clang;

  clang_34 = wrapGCC llvmPackages_34.clang;
  clang_33 = wrapGCC (clangUnwrapped llvm_33 ../development/compilers/llvm/3.3/clang.nix);

  clangAnalyzer = callPackage ../development/tools/analysis/clang-analyzer {
    clang = clang_34;
    llvmPackages = llvmPackages_34;
  };

  clangUnwrapped = llvm: pkg: callPackage pkg {
    inherit stdenv llvm;
  };

  clangSelf = clangWrapSelf llvmPackagesSelf.clang;

  clangWrapSelf = build: (import ../build-support/gcc-wrapper) {
    gcc = build;
    stdenv = clangStdenv;
    libc = glibc;
    binutils = binutils;
    inherit coreutils zlib;
    extraPackages = [ libcxx ];
    nativeTools = false;
    nativeLibc = false;
  };

  #Use this instead of stdenv to build with clang
  clangStdenv = if stdenv.isDarwin then stdenv else lowPrio (stdenvAdapters.overrideGCC stdenv clang);
  libcxxStdenv = stdenvAdapters.overrideGCC stdenv (clangWrapSelf llvmPackages.clang);

  clean = callPackage ../development/compilers/clean { };

  closurecompiler = callPackage ../development/compilers/closure { };

  cmucl_binary = callPackage ../development/compilers/cmucl/binary.nix { };

  compcert = callPackage ../development/compilers/compcert {};

  cryptol1 = lowPrio (callPackage ../development/compilers/cryptol/1.8.x.nix {});
  cryptol2 = with haskellPackages_ghc763; callPackage ../development/compilers/cryptol/2.0.x.nix {
    Cabal = Cabal_1_18_1_3;
    cabalInstall = cabalInstall_1_18_0_3.override {
      network = network_2_5_0_0;
      HTTP = HTTP.override { network = network_2_5_0_0; };
    };
    process = process_1_2_0_0;
  };

  cython = pythonPackages.cython;
  cython3 = python3Packages.cython;

  ecl = callPackage ../development/compilers/ecl { };

  eql = callPackage ../development/compilers/eql {};

  adobe_flex_sdk = callPackage ../development/compilers/adobe-flex-sdk { };

  fpc = callPackage ../development/compilers/fpc { };

  gambit = callPackage ../development/compilers/gambit { };

  gcc       = gcc48;
  gcc_multi = gcc48_multi;

  gccApple = throw "gccApple is no longer supported";

  gcc34 = wrapGCC (import ../development/compilers/gcc/3.4 {
    inherit fetchurl stdenv noSysDirs;
  });

  gcc48_realCross = lib.addMetaAttrs { hydraPlatforms = []; }
    (callPackage ../development/compilers/gcc/4.8 {
      inherit noSysDirs;
      binutilsCross = binutilsCross;
      libcCross = libcCross;
      profiledCompiler = false;
      enableMultilib = false;
      crossStageStatic = false;
      cross = assert crossSystem != null; crossSystem;
    });

  gcc_realCross = gcc48_realCross;

  gccCrossStageStatic = let
      libcCross1 =
        if stdenv.cross.libc == "msvcrt" then windows.mingw_w64_headers
        else if stdenv.cross.libc == "libSystem" then darwin.xcode
        else null;
    in
      wrapGCCCross {
      gcc = forceNativeDrv (lib.addMetaAttrs { hydraPlatforms = []; } (
        gcc_realCross.override {
          crossStageStatic = true;
          langCC = false;
          libcCross = libcCross1;
          enableShared = false;
        }));
      libc = libcCross1;
      binutils = binutilsCross;
      cross = assert crossSystem != null; crossSystem;
  };

  # Only needed for mingw builds
  gccCrossMingw2 = wrapGCCCross {
    gcc = gccCrossStageStatic.gcc;
    libc = windows.mingw_headers2;
    binutils = binutilsCross;
    cross = assert crossSystem != null; crossSystem;
  };

  gccCrossStageFinal = wrapGCCCross {
    gcc = forceNativeDrv (gcc_realCross.override {
      libpthreadCross =
        # FIXME: Don't explicitly refer to `i586-pc-gnu'.
        if crossSystem != null && crossSystem.config == "i586-pc-gnu"
        then gnu.libpthreadCross
        else null;

      # XXX: We have troubles cross-compiling libstdc++ on MinGW (see
      # <http://hydra.nixos.org/build/4268232>), so don't even try.
      langCC = (crossSystem == null
                || crossSystem.config != "i686-pc-mingw32");
     });
    libc = libcCross;
    binutils = binutilsCross;
    cross = assert crossSystem != null; crossSystem;
  };

  gcc44 = lowPrio (wrapGCC (makeOverridable (import ../development/compilers/gcc/4.4) {
    inherit fetchurl stdenv gmp mpfr /* ppl cloogppl */
      gettext which noSysDirs;
    texinfo = texinfo4;
    profiledCompiler = true;
  }));

  gcc45 = lowPrio (wrapGCC (callPackage ../development/compilers/gcc/4.5 {
    inherit fetchurl stdenv gmp mpfr mpc libelf zlib perl
      gettext which noSysDirs;
    texinfo = texinfo4;

    ppl = null;
    cloogppl = null;

    # bootstrapping a profiled compiler does not work in the sheevaplug:
    # http://gcc.gnu.org/bugzilla/show_bug.cgi?id=43944
    profiledCompiler = !stdenv.isArm;

    # When building `gcc.crossDrv' (a "Canadian cross", with host == target
    # and host != build), `cross' must be null but the cross-libc must still
    # be passed.
    cross = null;
    libcCross = if crossSystem != null then libcCross else null;
    libpthreadCross =
      if crossSystem != null && crossSystem.config == "i586-pc-gnu"
      then gnu.libpthreadCross
      else null;
  }));

  gcc46 = lowPrio (wrapGCC (callPackage ../development/compilers/gcc/4.6 {
    inherit noSysDirs;

    ppl = null;
    cloog = null;

    # bootstrapping a profiled compiler does not work in the sheevaplug:
    # http://gcc.gnu.org/bugzilla/show_bug.cgi?id=43944
    profiledCompiler = false;

    # When building `gcc.crossDrv' (a "Canadian cross", with host == target
    # and host != build), `cross' must be null but the cross-libc must still
    # be passed.
    cross = null;
    libcCross = if crossSystem != null then libcCross else null;
    libpthreadCross =
      if crossSystem != null && crossSystem.config == "i586-pc-gnu"
      then gnu.libpthreadCross
      else null;
    texinfo = texinfo413;
  }));

  gcc48 = lowPrio (wrapGCC (callPackage ../development/compilers/gcc/4.8 {
    inherit noSysDirs;

    # PGO seems to speed up compilation by gcc by ~10%, see #445 discussion
    profiledCompiler = with stdenv; (!isDarwin && (isi686 || isx86_64));

    # When building `gcc.crossDrv' (a "Canadian cross", with host == target
    # and host != build), `cross' must be null but the cross-libc must still
    # be passed.
    cross = null;
    libcCross = if crossSystem != null then libcCross else null;
    libpthreadCross =
      if crossSystem != null && crossSystem.config == "i586-pc-gnu"
      then gnu.libpthreadCross
      else null;
  }));

  gcc48_multi =
    if system == "x86_64-linux" then lowPrio (
      wrapGCCWith (import ../build-support/gcc-wrapper) glibc_multi (gcc48.gcc.override {
        stdenv = overrideGCC stdenv (wrapGCCWith (import ../build-support/gcc-wrapper) glibc_multi gcc.gcc);
        profiledCompiler = false;
        enableMultilib = true;
      }))
    else throw "Multilib gcc not supported on ‘${system}’";

  gcc48_debug = lowPrio (wrapGCC (callPackage ../development/compilers/gcc/4.8 {
    stripped = false;

    inherit noSysDirs;
    cross = null;
    libcCross = null;
    binutilsCross = null;
  }));

  gcc49 = lowPrio (wrapGCC (callPackage ../development/compilers/gcc/4.9 {
    inherit noSysDirs;

    # PGO seems to speed up compilation by gcc by ~10%, see #445 discussion
    profiledCompiler = with stdenv; (!isDarwin && (isi686 || isx86_64));

    # When building `gcc.crossDrv' (a "Canadian cross", with host == target
    # and host != build), `cross' must be null but the cross-libc must still
    # be passed.
    cross = null;
    libcCross = if crossSystem != null then libcCross else null;
    libpthreadCross =
      if crossSystem != null && crossSystem.config == "i586-pc-gnu"
      then gnu.libpthreadCross
      else null;
  }));

  gfortran = gfortran48;

  gfortran48 = wrapGCC (gcc48.gcc.override {
    name = "gfortran";
    langFortran = true;
    langCC = false;
    langC = false;
    profiledCompiler = false;
  });

  gcj = gcj48;

  gcj48 = wrapGCC (gcc48.gcc.override {
    name = "gcj";
    langJava = true;
    langFortran = false;
    langCC = false;
    langC = false;
    profiledCompiler = false;
    inherit zip unzip zlib boehmgc gettext pkgconfig perl;
    inherit gtk;
    inherit (gnome) libart_lgpl;
    inherit (xlibs) libX11 libXt libSM libICE libXtst libXi libXrender
      libXrandr xproto renderproto xextproto inputproto randrproto;
  });

  gnat = gnat45;

  gnat45 = wrapGCC (gcc45.gcc.override {
    name = "gnat";
    langCC = false;
    langC = true;
    langAda = true;
    profiledCompiler = false;
    inherit gnatboot;
    # We can't use the ppl stuff, because we would have
    # libstdc++ problems.
    cloogppl = null;
    ppl = null;
  });

  gnat46 = wrapGCC (gcc46.gcc.override {
    name = "gnat";
    langCC = false;
    langC = true;
    langAda = true;
    profiledCompiler = false;
    gnatboot = gnat45;
    # We can't use the ppl stuff, because we would have
    # libstdc++ problems.
    ppl = null;
    cloog = null;
  });

  gnatboot = wrapGCC (import ../development/compilers/gnatboot {
    inherit fetchurl stdenv;
  });

  gccgo = gccgo48;

  gccgo48 = wrapGCC (gcc48.gcc.override {
    name = "gccgo";
    langCC = true; #required for go.
    langC = true;
    langGo = true;
  });

  ghdl = wrapGCC (import ../development/compilers/gcc/4.3 {
    inherit stdenv fetchurl gmp mpfr noSysDirs gnat;
    texinfo = texinfo4;
    name = "ghdl";
    langVhdl = true;
    langCC = false;
    langC = false;
    profiledCompiler = false;
    enableMultilib = false;
  });

  ghdl_mcode = callPackage ../development/compilers/ghdl { };

  gcl = builderDefsPackage ../development/compilers/gcl {
    inherit mpfr m4 binutils fetchcvs emacs zlib which
      texinfo;
    gmp = gmp4;
    inherit (xlibs) libX11 xproto inputproto libXi
      libXext xextproto libXt libXaw libXmu;
    inherit stdenv;
    texLive = texLiveAggregationFun {
      paths = [
        texLive texLiveExtra
      ];
    };
  };

  jhc = callPackage ../development/compilers/jhc {
    inherit (haskellPackages_ghc763) ghc binary zlib utf8String readline fgl
      regexCompat HsSyck random;
  };

  gcc-arm-embedded-4_7 = callPackage_i686 ../development/compilers/gcc-arm-embedded {
    version = "4.7-2013q3-20130916";
    releaseType = "update";
    sha256 = "1bd9bi9q80xn2rpy0rn1vvj70rh15kb7dmah0qs4q2rv78fqj40d";
  };
  gcc-arm-embedded-4_8 = callPackage_i686 ../development/compilers/gcc-arm-embedded {
    version = "4.8-2014q1-20140314";
    releaseType = "update";
    sha256 = "ce92859550819d4a3d1a6e2672ea64882b30afa2c08cf67fa8e1d93788c2c577";
  };
  gcc-arm-embedded = gcc-arm-embedded-4_8;

  gforth = callPackage ../development/compilers/gforth {};

  # Haskell and GHC

  # Import Haskell infrastructure.

  haskell = let pkgs_       = pkgs // { gmp = gmp.override { withStatic = true; }; };
                callPackage = newScope pkgs_;
                newScope    = extra: lib.callPackageWith (pkgs_ // pkgs_.xorg // extra);
            in callPackage ./haskell-defaults.nix { pkgs = pkgs_; inherit callPackage newScope; };

  # Available GHC versions.

  # For several compiler versions, we export a large set of Haskell-related
  # packages.

  # NOTE (recurseIntoAttrs): After discussion, we originally decided to
  # enable it for all GHC versions. However, this is getting too much,
  # particularly in connection with Hydra builds for all these packages.
  # So we enable it for selected versions only. We build all ghcs, though

  ghc = recurseIntoAttrs (lib.mapAttrs' (name: value:
    lib.nameValuePair (builtins.substring (builtins.stringLength "packages_") (builtins.stringLength name) name) value.ghc
  ) (lib.filterAttrs (name: value:
    builtins.substring 0 (builtins.stringLength "packages_") name == "packages_"
  ) haskell));

  haskellPackages = haskellPackages_ghc783;

  haskellPackages_ghc6104 = haskell.packages_ghc6104;
  haskellPackages_ghc6123 = haskell.packages_ghc6123;
  haskellPackages_ghc704  = haskell.packages_ghc704;
  haskellPackages_ghc722  = haskell.packages_ghc722;
  haskellPackages_ghc742  = haskell.packages_ghc742;
  haskellPackages_ghc763  = haskell.packages_ghc763;
  haskellPackages_ghc783_no_profiling = recurseIntoAttrs haskell.packages_ghc783.noProfiling;
  haskellPackages_ghc783_profiling    = recurseIntoAttrs haskell.packages_ghc783.profiling;
  haskellPackages_ghc783              = recurseIntoAttrs haskell.packages_ghc783.highPrio;
  haskellPackages_ghcHEAD = haskell.packages_ghcHEAD;

  haxe = callPackage ../development/compilers/haxe { };

  hhvm = callPackage ../development/compilers/hhvm { };
  hiphopvm = hhvm; /* Compatibility alias */

  falcon = callPackage ../development/interpreters/falcon { };

  fsharp = callPackage ../development/compilers/fsharp {};

  gem-nix = callPackage ../tools/package-management/gem-nix { };

  go_1_0 = callPackage ../development/compilers/go { };

  go_1_1 =
    if stdenv.isDarwin then
      callPackage ../development/compilers/go/1.1-darwin.nix { }
    else
      callPackage ../development/compilers/go/1.1.nix { };

  go_1_2 = callPackage ../development/compilers/go/1.2.nix { };

  go_1_3 = callPackage ../development/compilers/go/1.3.nix { };

  go = go_1_3;

  go-repo-root = callPackage ../development/tools/misc/go-repo-root { };

  go-bindata = callPackage ../tools/misc/go-bindata { };

  gox = callPackage ../development/compilers/go/gox.nix { };

  gprolog = callPackage ../development/compilers/gprolog { };

  gwt240 = callPackage ../development/compilers/gwt/2.4.0.nix { };

  icedtea7_jdk = callPackage ../development/compilers/icedtea rec {
    jdk = openjdk;
    jdkPath = "${openjdk}/lib/openjdk";
    giflib = giflib_5_0;
  } // { outputs = [ "out" ]; };

  icedtea7_jre = (lib.setName "icedtea7-${lib.getVersion pkgs.icedtea7_jdk.jre}" (lib.addMetaAttrs
    { description = "Free Java runtime environment based on OpenJDK 7.0 and the IcedTea project"; }
    pkgs.icedtea7_jdk.jre)) // { outputs = [ "jre" ]; };

  icedtea7_web = callPackage ../development/compilers/icedtea-web {
    jdk = "${icedtea7_jdk}/lib/icedtea";
    xulrunner = firefox;
  };

  ikarus = callPackage ../development/compilers/ikarus { };

  hugs = callPackage ../development/compilers/hugs { };

  path64 = callPackage ../development/compilers/path64 { };

  openjdk =
    if stdenv.isDarwin then
      callPackage ../development/compilers/openjdk-darwin { }
    else
      let
        openjdkBootstrap = callPackage ../development/compilers/openjdk/bootstrap.nix { };
      in (callPackage ../development/compilers/openjdk {
        jdk = openjdkBootstrap;
      }) // { outputs = [ "out" ]; };

  # FIXME: Need a way to set per-output meta attributes.
  openjre = (lib.setName "openjre-${lib.getVersion pkgs.openjdk.jre}" (lib.addMetaAttrs
    { description = "The open-source Java Runtime Environment"; }
    pkgs.openjdk.jre)) // { outputs = [ "jre" ]; };

  jdk = if stdenv.isDarwin || stdenv.system == "i686-linux" || stdenv.system == "x86_64-linux"
    then pkgs.openjdk
    else pkgs.oraclejdk;
  jre = if stdenv.isDarwin || stdenv.system == "i686-linux" || stdenv.system == "x86_64-linux"
    then pkgs.openjre
    else pkgs.oraclejre;

  oraclejdk = pkgs.jdkdistro true false;

  oraclejdk7 = pkgs.oraclejdk7distro true false;

  oraclejdk7psu = pkgs.oraclejdk7psu_distro true false;

  oraclejdk8 = pkgs.oraclejdk8distro true false;

  oraclejre = lowPrio (pkgs.jdkdistro false false);

  oraclejre7 = lowPrio (pkgs.oraclejdk7distro false false);

  oraclejre7psu = lowPrio (pkgs.oraclejdk7psu_distro false false);

  oraclejre8 = lowPrio (pkgs.oraclejdk8distro false false);

  jrePlugin = lowPrio (pkgs.jdkdistro false true);

  supportsJDK =
    system == "i686-linux" ||
    system == "x86_64-linux";

  jdkdistro = installjdk: pluginSupport:
    assert supportsJDK;
    (if pluginSupport then appendToName "with-plugin" else x: x)
      (callPackage ../development/compilers/oraclejdk/jdk6-linux.nix { });

  oraclejdk7distro = installjdk: pluginSupport:
    assert supportsJDK;
    (if pluginSupport then appendToName "with-plugin" else x: x)
      (callPackage ../development/compilers/oraclejdk/jdk7-linux.nix { inherit installjdk; });

  oraclejdk7psu_distro = installjdk: pluginSupport:
    assert supportsJDK;
    (if pluginSupport then appendToName "with-plugin" else x: x)
      (callPackage ../development/compilers/oraclejdk/jdk7psu-linux.nix { inherit installjdk; });

  oraclejdk8distro = installjdk: pluginSupport:
    assert supportsJDK;
    (if pluginSupport then appendToName "with-plugin" else x: x)
      (callPackage ../development/compilers/oraclejdk/jdk8-linux.nix { inherit installjdk; });

  jikes = callPackage ../development/compilers/jikes { };

  julia021 = callPackage ../development/compilers/julia/0.2.1.nix {
    liblapack = liblapack.override {shared = true;};
    llvm = llvm_33;
    openblas = openblas_0_2_2;
  };

  julia032 = let
    liblapack = liblapack_3_5_0.override {shared = true;};
  in callPackage ../development/compilers/julia/0.3.2.nix {
    inherit liblapack;
    suitesparse = suitesparse.override {
      inherit liblapack;
    };
    llvm = llvm_34;
    openblas = openblas_0_2_10;
  };
  julia = julia032;

  lazarus = callPackage ../development/compilers/fpc/lazarus.nix {
    fpc = fpc;
  };

  lessc = callPackage ../development/compilers/lessc { };

  llvm = llvmPackages.llvm;

  llvm_34 = llvmPackages_34.llvm;
  llvm_33 = llvm_v ../development/compilers/llvm/3.3/llvm.nix;

  llvm_v = path: callPackage path { };

  llvmPackages = llvmPackages_34;

  llvmPackages_34 = recurseIntoAttrs (import ../development/compilers/llvm/3.4 {
    inherit stdenv newScope fetchurl;
    isl = isl_0_12;
  });
  llvmPackagesSelf = import ../development/compilers/llvm/3.4 { inherit newScope fetchurl; isl = isl_0_12; stdenv = libcxxStdenv; };

  manticore = callPackage ../development/compilers/manticore { };

  mentorToolchains = recurseIntoAttrs (
    callPackage_i686 ../development/compilers/mentor {}
  );

  mercury = callPackage ../development/compilers/mercury { };

  mitscheme = callPackage ../development/compilers/mit-scheme { };

  mlton = callPackage ../development/compilers/mlton { };

  mono = callPackage ../development/compilers/mono {
    inherit (xlibs) libX11;
  };

  monoDLLFixer = callPackage ../build-support/mono-dll-fixer { };

  mozart-binary = callPackage ../development/compilers/mozart/binary.nix { };
  mozart = mozart-binary;

  neko = callPackage ../development/compilers/neko { };

  nasm = callPackage ../development/compilers/nasm { };

  nvidia_cg_toolkit = callPackage ../development/compilers/nvidia-cg-toolkit { };

  ocaml = ocamlPackages.ocaml;

  ocaml_3_08_0 = callPackage ../development/compilers/ocaml/3.08.0.nix { };

  ocaml_3_10_0 = callPackage ../development/compilers/ocaml/3.10.0.nix { };

  ocaml_3_11_2 = callPackage ../development/compilers/ocaml/3.11.2.nix { };

  ocaml_3_12_1 = callPackage ../development/compilers/ocaml/3.12.1.nix { };

  ocaml_4_00_1 = callPackage ../development/compilers/ocaml/4.00.1.nix { };

  ocaml_4_01_0 = callPackage ../development/compilers/ocaml/4.01.0.nix { };

  ocaml_4_02_1 = callPackage ../development/compilers/ocaml/4.02.1.nix { };

  orc = callPackage ../development/compilers/orc { };

  metaocaml_3_09 = callPackage ../development/compilers/ocaml/metaocaml-3.09.nix { };

  ber_metaocaml_003 = callPackage ../development/compilers/ocaml/ber-metaocaml-003.nix { };

  mkOcamlPackages = ocaml: self:
    let
      callPackage = newScope self;
      ocaml_version = (builtins.parseDrvName ocaml.name).version;
    in rec {
    inherit ocaml;

    acgtk = callPackage ../applications/science/logic/acgtk { };

    ansiterminal = callPackage ../development/ocaml-modules/ansiterminal { };

    bolt = callPackage ../development/ocaml-modules/bolt { };

    camlidl = callPackage ../development/tools/ocaml/camlidl { };

    camlp4 =
      if lib.versionOlder "4.02" ocaml_version
      then callPackage ../development/tools/ocaml/camlp4 { }
      else null;

    camlp5_old_strict =
      if lib.versionOlder "4.00" ocaml_version
      then camlp5_6_strict
      else callPackage ../development/tools/ocaml/camlp5/5.15.nix { };

    camlp5_old_transitional =
      if lib.versionOlder "4.00" ocaml_version
      then camlp5_6_transitional
      else callPackage ../development/tools/ocaml/camlp5/5.15.nix {
        transitional = true;
      };

    camlp5_6_strict = callPackage ../development/tools/ocaml/camlp5 { };

    camlp5_6_transitional = callPackage ../development/tools/ocaml/camlp5 {
      transitional = true;
    };

    camlp5_strict = camlp5_6_strict;

    camlp5_transitional = camlp5_6_transitional;

    camlpdf = callPackage ../development/ocaml-modules/camlpdf { };

    calendar = callPackage ../development/ocaml-modules/calendar { };

    camlzip = callPackage ../development/ocaml-modules/camlzip { };

    camomile_0_8_2 = callPackage ../development/ocaml-modules/camomile/0.8.2.nix { };
    camomile = callPackage ../development/ocaml-modules/camomile { };

    camlimages_4_0 = callPackage ../development/ocaml-modules/camlimages/4.0.nix {
      libpng = libpng12;
      giflib = giflib_4_1;
    };
    camlimages_4_1 = callPackage ../development/ocaml-modules/camlimages/4.1.nix {};
    camlimages = camlimages_4_1;

    biniou = callPackage ../development/ocaml-modules/biniou { };

    ocaml_cairo = callPackage ../development/ocaml-modules/ocaml-cairo { };

    ocaml_cairo2 = callPackage ../development/ocaml-modules/ocaml-cairo2 { };

    cil = callPackage ../development/ocaml-modules/cil { };

    cmdliner = callPackage ../development/ocaml-modules/cmdliner { };

    cppo = callPackage ../development/tools/ocaml/cppo { };

    cryptokit = callPackage ../development/ocaml-modules/cryptokit { };

    csv = callPackage ../development/ocaml-modules/csv { };

    deriving = callPackage ../development/tools/ocaml/deriving { };

    easy-format = callPackage ../development/ocaml-modules/easy-format { };

    eff = callPackage ../development/interpreters/eff { };

    eliom = callPackage ../development/ocaml-modules/eliom { };

    findlib = callPackage ../development/tools/ocaml/findlib { };

    fix = callPackage ../development/ocaml-modules/fix { };

    functory = callPackage ../development/ocaml-modules/functory { };

    javalib = callPackage ../development/ocaml-modules/javalib {
      extlib = ocaml_extlib_maximal;
    };

    dypgen = callPackage ../development/ocaml-modules/dypgen { };

    patoline = callPackage ../tools/typesetting/patoline { };

    gg = callPackage ../development/ocaml-modules/gg { };

    gmetadom = callPackage ../development/ocaml-modules/gmetadom { };

    js_of_ocaml = callPackage ../development/tools/ocaml/js_of_ocaml { };

    lablgl = callPackage ../development/ocaml-modules/lablgl { };

    lablgtk_2_14 = callPackage ../development/ocaml-modules/lablgtk/2.14.0.nix {
      inherit (gnome) libgnomecanvas libglade gtksourceview;
    };
    lablgtk = callPackage ../development/ocaml-modules/lablgtk {
      inherit (gnome) libgnomecanvas libglade gtksourceview;
    };

    lablgtkmathview = callPackage ../development/ocaml-modules/lablgtkmathview {
      gtkmathview = callPackage ../development/libraries/gtkmathview { };
    };

    lambdaTerm = callPackage ../development/ocaml-modules/lambda-term { };

    macaque = callPackage ../development/ocaml-modules/macaque { };

    menhir = callPackage ../development/ocaml-modules/menhir { };

    merlin = callPackage ../development/tools/ocaml/merlin { };

    mezzo = callPackage ../development/compilers/mezzo { };

    mldonkey = callPackage ../applications/networking/p2p/mldonkey { };

    mlgmp =  callPackage ../development/ocaml-modules/mlgmp { };

    ocaml_batteries = callPackage ../development/ocaml-modules/batteries { };

    ocaml_cryptgps = callPackage ../development/ocaml-modules/cryptgps { };

    ocaml_data_notation = callPackage ../development/ocaml-modules/odn { };

    ocaml_expat = callPackage ../development/ocaml-modules/expat { };

    ocamlgraph = callPackage ../development/ocaml-modules/ocamlgraph { };

    ocaml_http = callPackage ../development/ocaml-modules/http { };

    ocamlify = callPackage ../development/tools/ocaml/ocamlify { };

    ocaml_ipaddr = callPackage ../development/ocaml-modules/ocaml-ipaddr { };

    ocaml_lwt = callPackage ../development/ocaml-modules/lwt { };

    ocamlmod = callPackage ../development/tools/ocaml/ocamlmod { };

    ocaml_mysql = callPackage ../development/ocaml-modules/mysql { };

    ocamlnet = callPackage ../development/ocaml-modules/ocamlnet { };

    ocaml_oasis = callPackage ../development/tools/ocaml/oasis { };

    ocaml_optcomp = callPackage ../development/ocaml-modules/optcomp { };

    ocaml_pcre = callPackage ../development/ocaml-modules/pcre {
      inherit pcre;
    };

    pgocaml = callPackage ../development/ocaml-modules/pgocaml {};

    ocaml_react = callPackage ../development/ocaml-modules/react { };
    reactivedata = callPackage ../development/ocaml-modules/reactivedata {};

    ocamlscript = callPackage ../development/tools/ocaml/ocamlscript { };

    ocamlsdl= callPackage ../development/ocaml-modules/ocamlsdl { };

    ocaml_sqlite3 = callPackage ../development/ocaml-modules/sqlite3 { };

    ocaml_ssl = callPackage ../development/ocaml-modules/ssl { };

    ocaml_text = callPackage ../development/ocaml-modules/ocaml-text { };

    ocpBuild = callPackage ../development/tools/ocaml/ocp-build { };

    ocpIndent = callPackage ../development/tools/ocaml/ocp-indent { };

    ocsigen_server = callPackage ../development/ocaml-modules/ocsigen-server { };

    otfm = callPackage ../development/ocaml-modules/otfm { };

    ounit = callPackage ../development/ocaml-modules/ounit { };

    tyxml = callPackage ../development/ocaml-modules/tyxml { };

    ulex = callPackage ../development/ocaml-modules/ulex { };

    ulex08 = callPackage ../development/ocaml-modules/ulex/0.8 {
      camlp5 = camlp5_transitional;
    };

    typeconv_108_08_00 = callPackage ../development/ocaml-modules/typeconv/108.08.00.nix { };
    ocaml_typeconv =
      if lib.versionOlder "4.00" ocaml_version
      then callPackage ../development/ocaml-modules/typeconv { }
      else if lib.versionOlder "3.12" ocaml_version
      then typeconv_108_08_00
      else null;

    sexplib_108_08_00 = callPackage ../development/ocaml-modules/sexplib/108.08.00.nix {
      typeconv = typeconv_108_08_00;
    };
    ocaml_sexplib =
      if lib.versionOlder "4.00" ocaml_version
      then callPackage ../development/ocaml-modules/sexplib { }
      else if lib.versionOlder "3.12" ocaml_version
      then sexplib_108_08_00
      else null;

    ocaml_extlib = callPackage ../development/ocaml-modules/extlib { };
    ocaml_extlib_maximal = callPackage ../development/ocaml-modules/extlib {
      minimal = false;
    };

    pprint = callPackage ../development/ocaml-modules/pprint { };

    pycaml = callPackage ../development/ocaml-modules/pycaml { };

    sqlite3EZ = callPackage ../development/ocaml-modules/sqlite3EZ { };

    twt = callPackage ../development/ocaml-modules/twt { };

    utop = callPackage ../development/tools/ocaml/utop { };

    sawja = callPackage ../development/ocaml-modules/sawja { };

    uucd = callPackage ../development/ocaml-modules/uucd { };
    uunf = callPackage ../development/ocaml-modules/uunf { };
    uutf = callPackage ../development/ocaml-modules/uutf { };

    vg = callPackage ../development/ocaml-modules/vg { };

    xmlm = callPackage ../development/ocaml-modules/xmlm { };

    yojson = callPackage ../development/ocaml-modules/yojson { };

    zarith = callPackage ../development/ocaml-modules/zarith { };

    zed = callPackage ../development/ocaml-modules/zed { };

    ocsigen_deriving = callPackage ../development/ocaml-modules/ocsigen-deriving { };

  };

  ocamlPackages = recurseIntoAttrs ocamlPackages_4_01_0;
  ocamlPackages_3_10_0 = (mkOcamlPackages ocaml_3_10_0 pkgs.ocamlPackages_3_10_0)
  // { lablgtk = ocamlPackages_3_10_0.lablgtk_2_14; };
  ocamlPackages_3_11_2 = (mkOcamlPackages ocaml_3_11_2 pkgs.ocamlPackages_3_11_2)
  // { lablgtk = ocamlPackages_3_11_2.lablgtk_2_14; };
  ocamlPackages_3_12_1 = (mkOcamlPackages ocaml_3_12_1 pkgs.ocamlPackages_3_12_1)
  // { camlimages = ocamlPackages_3_12_1.camlimages_4_0; };
  ocamlPackages_4_00_1 = mkOcamlPackages ocaml_4_00_1 pkgs.ocamlPackages_4_00_1;
  ocamlPackages_4_01_0 = mkOcamlPackages ocaml_4_01_0 pkgs.ocamlPackages_4_01_0;
  ocamlPackages_4_02_1 = mkOcamlPackages ocaml_4_02_1 pkgs.ocamlPackages_4_02_1;
  ocamlPackages_latest = ocamlPackages_4_02_1;

  ocaml_make = callPackage ../development/ocaml-modules/ocamlmake { };

  opa = callPackage ../development/compilers/opa {
    ocamlPackages = ocamlPackages_4_00_1;
  };

  opam_1_0_0 = callPackage ../development/tools/ocaml/opam/1.0.0.nix { };
  opam_1_1 = callPackage ../development/tools/ocaml/opam/1.1.nix {
    inherit (ocamlPackages_4_01_0) ocaml;
  };
  opam_1_2_0 = callPackage ../development/tools/ocaml/opam/1.2.0.nix { };
  opam = opam_1_2_0;

  ocamlnat = let callPackage = newScope pkgs.ocamlPackages_3_12_1; in callPackage ../development/ocaml-modules/ocamlnat { };

  qcmm = callPackage ../development/compilers/qcmm {
    lua   = lua4;
    ocaml = ocaml_3_08_0;
  };

  rustc       = callPackage ../development/compilers/rustc/0.12.nix {};
  rustcMaster = callPackage ../development/compilers/rustc/head.nix {};

  rust = rustc;


  sbclBootstrap = callPackage ../development/compilers/sbcl/bootstrap.nix {};
  sbcl = callPackage ../development/compilers/sbcl {
    clisp = clisp;
  };
  # For ACL2
  sbcl_1_2_0 = callPackage ../development/compilers/sbcl/1.2.0.nix {
    clisp = clisp;
  };

  scala_2_9 = callPackage ../development/compilers/scala/2.9.nix { };
  scala_2_10 = callPackage ../development/compilers/scala/2.10.nix { };
  scala_2_11 = callPackage ../development/compilers/scala { };
  scala = scala_2_11;

  sdcc = callPackage ../development/compilers/sdcc { };

  smlnjBootstrap = callPackage ../development/compilers/smlnj/bootstrap.nix { };
  smlnj = callPackage_i686 ../development/compilers/smlnj { };

  stalin = callPackage ../development/compilers/stalin { };

  strategoPackages = recurseIntoAttrs strategoPackages018;

  strategoPackages016 = callPackage ../development/compilers/strategoxt/0.16.nix {
    stdenv = overrideInStdenv stdenv [gnumake380];
  };

  strategoPackages017 = callPackage ../development/compilers/strategoxt/0.17.nix {
    readline = readline5;
  };

  strategoPackages018 = callPackage ../development/compilers/strategoxt/0.18.nix {
    readline = readline5;
  };

  metaBuildEnv = callPackage ../development/compilers/meta-environment/meta-build-env { };

  swiProlog = callPackage ../development/compilers/swi-prolog { };

  tbb = callPackage ../development/libraries/tbb { };

  tinycc = callPackage ../development/compilers/tinycc { };

  urweb = callPackage ../development/compilers/urweb { };

  vala = callPackage ../development/compilers/vala/default.nix { };

  vala_0_26 = callPackage ../development/compilers/vala/0.26.nix { };

  visualcpp = callPackage ../development/compilers/visual-c++ { };

  vs90wrapper = callPackage ../development/compilers/vs90wrapper { };

  webdsl = callPackage ../development/compilers/webdsl { };

  win32hello = callPackage ../development/compilers/visual-c++/test { };

  wrapGCCWith = gccWrapper: glibc: baseGCC: gccWrapper {
    nativeTools = stdenv.gcc.nativeTools or false;
    nativeLibc = stdenv.gcc.nativeLibc or false;
    nativePrefix = stdenv.gcc.nativePrefix or "";
    gcc = baseGCC;
    libc = glibc;
    inherit stdenv binutils coreutils zlib;
  };

  wrapGCC = wrapGCCWith (makeOverridable (import ../build-support/gcc-wrapper)) glibc;

  wrapGCCCross =
    {gcc, libc, binutils, cross, shell ? "", name ? "gcc-cross-wrapper"}:

    forceNativeDrv (import ../build-support/gcc-cross-wrapper {
      nativeTools = false;
      nativeLibc = false;
      noLibc = (libc == null);
      inherit stdenv gcc binutils libc shell name cross;
    });

  # prolog
  yap = callPackage ../development/compilers/yap { };

  yasm = callPackage ../development/compilers/yasm { };


  ### DEVELOPMENT / INTERPRETERS

  acl2 = builderDefsPackage ../development/interpreters/acl2 {
    sbcl = sbcl_1_2_0;
  };

  angelscript = callPackage ../development/interpreters/angelscript {};

  chibi = callPackage ../development/interpreters/chibi { };

  clisp = callPackage ../development/interpreters/clisp { };

  # compatibility issues in 2.47 - at list 2.44.1 is known good
  # for sbcl bootstrap.
  # SBCL page recommends 2.33.2, though. Not sure when was it last tested
  clisp_2_44_1 = callPackage ../development/interpreters/clisp/2.44.1.nix {
    libsigsegv = libsigsegv_25;
  };

  clojure = callPackage ../development/interpreters/clojure { };

  clooj = callPackage ../development/interpreters/clojure/clooj.nix { };

  erlangR14 = callPackage ../development/interpreters/erlang/R14.nix { };
  erlangR15 = callPackage ../development/interpreters/erlang/R15.nix { };
  erlangR16 = callPackage ../development/interpreters/erlang/R16.nix { };
  erlangR16_odbc = callPackage ../development/interpreters/erlang/R16.nix { odbcSupport = true; };
  erlangR17 = callPackage ../development/interpreters/erlang/R17.nix { };
  erlangR17_odbc = callPackage ../development/interpreters/erlang/R17.nix { odbcSupport = true; };
  erlang = erlangR17;
  erlang_odbc = erlangR17_odbc;

  rebar = callPackage ../development/tools/build-managers/rebar { };

  elixir = callPackage ../development/interpreters/elixir { };

  groovy = callPackage ../development/interpreters/groovy { };

  guile_1_8 = callPackage ../development/interpreters/guile/1.8.nix { };

  guile_2_0 = callPackage ../development/interpreters/guile { };

  guile = guile_2_0;

  hadoop = callPackage ../applications/networking/cluster/hadoop { };

  io = callPackage ../development/interpreters/io { };

  j = callPackage ../development/interpreters/j {};

  jimtcl = callPackage ../development/interpreters/jimtcl {};

  jmeter = callPackage ../applications/networking/jmeter {};

  davmail = callPackage ../applications/networking/davmail {};

  lxappearance = callPackage ../applications/misc/lxappearance {};

  kona = callPackage ../development/interpreters/kona {};

  love = callPackage ../development/interpreters/love {lua=lua5_1;};
  love_luajit = callPackage ../development/interpreters/love {lua=luajit;};
  love_0_9 = callPackage ../development/interpreters/love/0.9.nix { };

  ### LUA MODULES

  lua4 = callPackage ../development/interpreters/lua-4 { };
  lua5_0 = callPackage ../development/interpreters/lua-5/5.0.3.nix { };
  lua5_1 = callPackage ../development/interpreters/lua-5/5.1.nix { };
  lua5_2 = callPackage ../development/interpreters/lua-5/5.2.nix { };
  lua5_2_compat = callPackage ../development/interpreters/lua-5/5.2.nix {
    compat = true;
  };
  lua5 = lua5_2_compat;
  lua = lua5;

  lua51Packages = recurseIntoAttrs (callPackage ./lua-packages.nix { lua = lua5_1; });
  lua52Packages = recurseIntoAttrs (callPackage ./lua-packages.nix { lua = lua5_2; });

  luaPackages = lua52Packages;

  lua5_1_sockets = lua51Packages.luasocket;

  lua5_expat = callPackage ../development/interpreters/lua-5/expat.nix {};
  lua5_sec = callPackage ../development/interpreters/lua-5/sec.nix { };

  luajit = callPackage ../development/interpreters/luajit {};

  luarocks = luaPackages.luarocks;

  ### END OF LUA

  lush2 = callPackage ../development/interpreters/lush {};

  maude = callPackage ../development/interpreters/maude {
    bison = bison2;
    flex = flex_2_5_35;
  };

  mesos = callPackage ../applications/networking/cluster/mesos {
    sasl = cyrus_sasl;
    automake = automake114x;
    inherit (pythonPackages) python boto setuptools distutils-cfg wrapPython;
    pythonProtobuf = pythonPackages.protobuf;
  };

  nix-exec = callPackage ../development/interpreters/nix-exec {
    nix = nixUnstable;
    git = gitMinimal;
  };

  octave = callPackage ../development/interpreters/octave {
    fltk = fltk13;
    qt = null;
    ghostscript = null;
    llvm = null;
    hdf5 = null;
    glpk = null;
    suitesparse = null;
    openjdk = null;
    gnuplot = null;
  };
  octaveFull = (lowPrio (callPackage ../development/interpreters/octave {
    fltk = fltk13;
    qt = qt4;
  }));

  # mercurial (hg) bleeding edge version
  octaveHG = callPackage ../development/interpreters/octave/hg.nix { };

  ocropus = callPackage ../applications/misc/ocropus { };

  perl514 = callPackage ../development/interpreters/perl/5.14 { };

  perl516 = callPackage ../development/interpreters/perl/5.16 {
    fetchurl = fetchurlBoot;
  };

  perl520 = callPackage ../development/interpreters/perl/5.20 { };

  perl = if system != "i686-cygwin" then perl516 else sysPerl;

  php = php54;

  phpPackages = recurseIntoAttrs (import ./php-packages.nix {
    inherit php pkgs;
  });

  php53 = callPackage ../development/interpreters/php/5.3.nix { };

  php_fpm53 = callPackage ../development/interpreters/php/5.3.nix {
    config = config // {
      php = (config.php or {}) // {
        fpm = true;
        apxs2 = false;
      };
    };
  };

  php54 = callPackage ../development/interpreters/php/5.4.nix { };

  picolisp = callPackage ../development/interpreters/picolisp {};

  pltScheme = racket; # just to be sure

  polyml = callPackage ../development/compilers/polyml { };

  pure = callPackage ../development/interpreters/pure { };
  pure-gsl = callPackage ../development/pure-modules/pure-gsl { };

  python = python2;
  python2 = python27;
  python3 = python34;

  # pythonPackages further below, but assigned here because they need to be in sync
  pythonPackages = python2Packages;
  python2Packages = python27Packages;
  python3Packages = python34Packages;

  python26 = callPackage ../development/interpreters/python/2.6 {
    db = db47;
    self = python26;
  };
  python27 = callPackage ../development/interpreters/python/2.7 {
    self = python27;
  };
  python32 = callPackage ../development/interpreters/python/3.2 {
    self = python32;
  };
  python33 = callPackage ../development/interpreters/python/3.3 {
    self = python33;
  };
  python34 = hiPrio (callPackage ../development/interpreters/python/3.4 {
    self = python34;
  });
  pypy = callPackage ../development/interpreters/pypy/2.4 {
    self = pypy;
  };

  pythonFull = python2Full;
  python2Full = python27Full;
  python26Full = python26.override {
    includeModules = true;
    self = python26Full;
  };
  python27Full = python27.override {
    includeModules = true;
    self = python27Full;
  };

  python2nix = callPackage ../tools/package-management/python2nix { };

  pythonDocs = recurseIntoAttrs (import ../development/interpreters/python/docs {
    inherit stdenv fetchurl lib;
  });

  pypi2nix = python27Packages.pypi2nix;

  svg2tikz = python27Packages.svg2tikz;

  pyrex = pyrex095;

  pyrex095 = callPackage ../development/interpreters/pyrex/0.9.5.nix { };

  pyrex096 = callPackage ../development/interpreters/pyrex/0.9.6.nix { };

  qi = callPackage ../development/compilers/qi { };

  racket = callPackage ../development/interpreters/racket { };

  rakudo = callPackage ../development/interpreters/rakudo { };

  rascal = callPackage ../development/interpreters/rascal { };

  regina = callPackage ../development/interpreters/regina { };

  renpy = callPackage ../development/interpreters/renpy {
    wrapPython = pythonPackages.wrapPython;
  };

  ruby_1_8_7 = callPackage ../development/interpreters/ruby/ruby-1.8.7.nix { };
  ruby_1_9_3 = callPackage ../development/interpreters/ruby/ruby-1.9.3.nix { };
  ruby_2_0_0 = lowPrio (callPackage ../development/interpreters/ruby/ruby-2.0.0.nix { });
  ruby_2_1_0 = lowPrio (callPackage ../development/interpreters/ruby/ruby-2.1.0.nix { });
  ruby_2_1_1 = lowPrio (callPackage ../development/interpreters/ruby/ruby-2.1.1.nix { });
  ruby_2_1_2 = lowPrio (callPackage ../development/interpreters/ruby/ruby-2.1.2.nix { });
  ruby_2_1_3 = lowPrio (callPackage ../development/interpreters/ruby/ruby-2.1.3.nix { });

  # Ruby aliases
  ruby = ruby_1_9;
  ruby_1_8 = ruby_1_8_7;
  ruby_1_9 = ruby_1_9_3;
  ruby_2_0 = ruby_2_0_0;
  ruby_2_1 = ruby_2_1_3;

  rubyLibs = recurseIntoAttrs (callPackage ../development/interpreters/ruby/libs.nix { });

  rake = rubyLibs.rake;

  rubySqlite3 = callPackage ../development/ruby-modules/sqlite3 { };

  rubygemsFun = ruby: builderDefsPackage (import ../development/interpreters/ruby/rubygems.nix) {
    inherit ruby makeWrapper;
  };
  rubygems = hiPrio (rubygemsFun ruby);

  rq = callPackage ../applications/networking/cluster/rq { };

  scsh = callPackage ../development/interpreters/scsh { };

  scheme48 = callPackage ../development/interpreters/scheme48 { };

  self = callPackage_i686 ../development/interpreters/self { };

  spark = callPackage ../applications/networking/cluster/spark { };

  spidermonkey = callPackage ../development/interpreters/spidermonkey { };
  spidermonkey_1_8_0rc1 = callPackage ../development/interpreters/spidermonkey/1.8.0-rc1.nix { };
  spidermonkey_185 = callPackage ../development/interpreters/spidermonkey/185-1.0.0.nix { };
  spidermonkey_17 = callPackage ../development/interpreters/spidermonkey/17.0.nix { };
  spidermonkey_24 = callPackage ../development/interpreters/spidermonkey/24.2.nix { };

  supercollider = callPackage ../development/interpreters/supercollider {
    qt = qt4;
    fftw = fftwSinglePrec;
  };

  supercollider_scel = supercollider.override { useSCEL = true; };

  sysPerl = callPackage ../development/interpreters/perl/sys-perl { };

  tcl = callPackage ../development/interpreters/tcl { };

  xulrunner = callPackage ../development/interpreters/xulrunner {
    inherit (gnome) libIDL;
    inherit (pythonPackages) pysqlite;
  };


  ### DEVELOPMENT / MISC

  amdadlsdk = callPackage ../development/misc/amdadl-sdk { };

  amdappsdk26 = callPackage ../development/misc/amdapp-sdk {
    version = "2.6";
  };

  amdappsdk27 = callPackage ../development/misc/amdapp-sdk {
    version = "2.7";
  };

  amdappsdk28 = callPackage ../development/misc/amdapp-sdk {
    version = "2.8";
  };

  amdappsdk = amdappsdk28;

  amdappsdkFull = callPackage ../development/misc/amdapp-sdk {
    version = "2.8";
    samples = true;
  };

  avrgcclibc = callPackage ../development/misc/avr-gcc-with-avr-libc {
    gcc = gcc46;
    stdenv = overrideGCC stdenv gcc46;
  };

  avr8burnomat = callPackage ../development/misc/avr8-burn-omat { };

  sourceFromHead = import ../build-support/source-from-head-fun.nix {
    inherit config;
  };

  ecj = callPackage ../development/eclipse/ecj { };

  jdtsdk = callPackage ../development/eclipse/jdt-sdk { };

  jruby165 = callPackage ../development/interpreters/jruby { };

  guileCairo = callPackage ../development/guile-modules/guile-cairo { };

  guileGnome = callPackage ../development/guile-modules/guile-gnome {
    gconf = gnome.GConf;
    inherit (gnome) gnome_vfs libglade libgnome libgnomecanvas libgnomeui;
  };

  guile_lib = callPackage ../development/guile-modules/guile-lib { };

  guile_ncurses = callPackage ../development/guile-modules/guile-ncurses { };

  guile-opengl = callPackage ../development/guile-modules/guile-opengl { };

  guile-sdl = callPackage ../development/guile-modules/guile-sdl { };

  guile-xcb = callPackage ../development/guile-modules/guile-xcb { };

  pharo-vm = callPackage_i686 ../development/pharo/vm { };
  pharo-launcher = callPackage ../development/pharo/launcher { };

  srecord = callPackage ../development/tools/misc/srecord { };

  windowssdk = (
    import ../development/misc/windows-sdk {
      inherit fetchurl stdenv cabextract;
    });


  ### DEVELOPMENT / TOOLS

  augeas = callPackage ../tools/system/augeas { };

  ansible = callPackage ../tools/system/ansible { };

  antlr = callPackage ../development/tools/parsing/antlr/2.7.7.nix { };

  antlr3 = callPackage ../development/tools/parsing/antlr { };

  ant = apacheAnt;

  apacheAnt = callPackage ../development/tools/build-managers/apache-ant { };

  astyle = callPackage ../development/tools/misc/astyle { };

  atom-shell = callPackage ../development/tools/atom-shell {
    gconf = pkgs.gnome.GConf;
  };


  autobuild = callPackage ../development/tools/misc/autobuild { };

  autoconf = callPackage ../development/tools/misc/autoconf { };

  autoconf213 = callPackage ../development/tools/misc/autoconf/2.13.nix { };

  autocutsel = callPackage ../tools/X11/autocutsel{ };

  automake = automake112x;

  automake111x = callPackage ../development/tools/misc/automake/automake-1.11.x.nix { };

  automake112x = callPackage ../development/tools/misc/automake/automake-1.12.x.nix { };

  automake113x = callPackage ../development/tools/misc/automake/automake-1.13.x.nix { };

  automake114x = callPackage ../development/tools/misc/automake/automake-1.14.x.nix { };

  automoc4 = callPackage ../development/tools/misc/automoc4 { };

  avrdude = callPackage ../development/tools/misc/avrdude { };

  avarice = callPackage ../development/tools/misc/avarice { };

  babeltrace = callPackage ../development/tools/misc/babeltrace { };

  bam = callPackage ../development/tools/build-managers/bam {};

  binutils = if stdenv.isDarwin
    then import ../build-support/native-darwin-cctools-wrapper {inherit stdenv;}
    else callPackage ../development/tools/misc/binutils {
      inherit noSysDirs;
    };

  binutils_nogold = lowPrio (callPackage ../development/tools/misc/binutils {
    inherit noSysDirs;
    gold = false;
  });

  binutilsCross =
    if crossSystem != null && crossSystem.libc == "libSystem" then darwin.cctools
    else lowPrio (forceNativeDrv (import ../development/tools/misc/binutils {
      inherit stdenv fetchurl zlib bison;
      noSysDirs = true;
      cross = assert crossSystem != null; crossSystem;
    }));

  bison2 = callPackage ../development/tools/parsing/bison/2.x.nix { };
  bison3 = callPackage ../development/tools/parsing/bison/3.x.nix { };
  bison = bison3;

  bossa = callPackage ../development/tools/misc/bossa {
    wxGTK = wxGTK30;
  };

  buildbot = callPackage ../development/tools/build-managers/buildbot {
    inherit (pythonPackages) twisted jinja2 sqlalchemy sqlalchemy_migrate;
    dateutil = pythonPackages.dateutil_1_5;
  };

  buildbotSlave = callPackage ../development/tools/build-managers/buildbot-slave {
    inherit (pythonPackages) twisted;
  };

  byacc = callPackage ../development/tools/parsing/byacc { };

  cargoSnapshot = callPackage ../development/tools/build-managers/cargo/snapshot.nix { };

  casperjs = callPackage ../development/tools/casperjs { };

  cbrowser = callPackage ../development/tools/misc/cbrowser { };

  ccache = callPackage ../development/tools/misc/ccache { };

  # Wrapper that works as gcc or g++
  # It can be used by setting in nixpkgs config like this, for example:
  #    replaceStdenv = { pkgs }: pkgs.ccacheStdenv;
  # But if you build in chroot, you should have that path in chroot
  # If instantiated directly, it will use the HOME/.ccache as cache directory.
  # You can use an override in packageOverrides to set extraConfig:
  #    packageOverrides = pkgs: {
  #     ccacheWrapper = pkgs.ccacheWrapper.override {
  #       extraConfig = ''
  #         CCACHE_COMPRESS=1
  #         CCACHE_DIR=/bin/.ccache
  #       '';
  #     };
  #
  ccacheWrapper = makeOverridable ({ extraConfig ? "" }:
     wrapGCC (ccache.links extraConfig)) {};
  ccacheStdenv = lowPrio (overrideGCC stdenv ccacheWrapper);

  cccc = callPackage ../development/tools/analysis/cccc { };

  cgdb = callPackage ../development/tools/misc/cgdb { };

  chromedriver = callPackage ../development/tools/selenium/chromedriver { gconf = gnome.GConf; };

  chrpath = callPackage ../development/tools/misc/chrpath { };

  chruby = callPackage ../development/tools/misc/chruby { rubies = null; };

  "cl-launch" = callPackage ../development/tools/misc/cl-launch {};

  complexity = callPackage ../development/tools/misc/complexity { };

  ctags = callPackage ../development/tools/misc/ctags { };

  ctagsWrapped = import ../development/tools/misc/ctags/wrapped.nix {
    inherit pkgs ctags writeScriptBin;
  };

  cmake = callPackage ../development/tools/build-managers/cmake { };

  cmake-3_0 = callPackage ../development/tools/build-managers/cmake/3.0.nix { };
  cmake264 = callPackage ../development/tools/build-managers/cmake/264.nix { };

  cmakeCurses = cmake.override { useNcurses = true; };

  cmakeWithGui = cmakeCurses.override { useQt4 = true; };

  coccinelle = callPackage ../development/tools/misc/coccinelle { };

  framac = callPackage ../development/tools/analysis/frama-c { };

  cppi = callPackage ../development/tools/misc/cppi { };

  cproto = callPackage ../development/tools/misc/cproto { };

  cflow = callPackage ../development/tools/misc/cflow { };

  cov-build = callPackage ../development/tools/analysis/cov-build {};

  cppcheck = callPackage ../development/tools/analysis/cppcheck { };

  cscope = callPackage ../development/tools/misc/cscope { };

  csslint = callPackage ../development/web/csslint { };

  libcxx = callPackage ../development/libraries/libc++ { stdenv = pkgs.clangStdenv; };
  libcxxabi = callPackage ../development/libraries/libc++abi { stdenv = pkgs.clangStdenv; };

  libsigrok = callPackage ../development/tools/libsigrok { };

  libsigrokdecode = callPackage ../development/tools/libsigrokdecode { };

  dejagnu = callPackage ../development/tools/misc/dejagnu { };

  dfeet = callPackage ../development/tools/misc/d-feet {
    inherit (pythonPackages) pep8;
  };

  dfu-programmer = callPackage ../development/tools/misc/dfu-programmer { };

  ddd = callPackage ../development/tools/misc/ddd { };

  distcc = callPackage ../development/tools/misc/distcc { };

  # distccWrapper: wrapper that works as gcc or g++
  # It can be used by setting in nixpkgs config like this, for example:
  #    replaceStdenv = { pkgs }: pkgs.distccStdenv;
  # But if you build in chroot, a default 'nix' will create
  # a new net namespace, and won't have network access.
  # You can use an override in packageOverrides to set extraConfig:
  #    packageOverrides = pkgs: {
  #     distccWrapper = pkgs.distccWrapper.override {
  #       extraConfig = ''
  #         DISTCC_HOSTS="myhost1 myhost2"
  #       '';
  #     };
  #
  distccWrapper = makeOverridable ({ extraConfig ? "" }:
     wrapGCC (distcc.links extraConfig)) {};
  distccStdenv = lowPrio (overrideGCC stdenv distccWrapper);

  distccMasquerade = if stdenv.isDarwin
    then null
    else callPackage ../development/tools/misc/distcc/masq.nix {
      gccRaw = gcc.gcc;
      binutils = binutils;
    };

  docutils = builderDefsPackage (import ../development/tools/documentation/docutils) {
    inherit python pil makeWrapper;
  };

  doxygen = callPackage ../development/tools/documentation/doxygen {
    qt4 = null;
  };

  doxygen_gui = lowPrio (doxygen.override { inherit qt4; });

  drush = callPackage ../development/tools/misc/drush { };

  eggdbus = callPackage ../development/tools/misc/eggdbus { };

  elfutils = callPackage ../development/tools/misc/elfutils { };

  epm = callPackage ../development/tools/misc/epm { };

  emma = callPackage ../development/tools/analysis/emma { };

  eztrace = callPackage ../development/tools/profiling/EZTrace { };

  findbugs = callPackage ../development/tools/analysis/findbugs { };

  flow = callPackage ../development/tools/analysis/flow { };

  pmd = callPackage ../development/tools/analysis/pmd { };

  jdepend = callPackage ../development/tools/analysis/jdepend { };

  checkstyle = callPackage ../development/tools/analysis/checkstyle { };

  flex_2_5_35 = callPackage ../development/tools/parsing/flex/2.5.35.nix { };
  flex_2_5_39 = callPackage ../development/tools/parsing/flex/2.5.39.nix { };
  flex = flex_2_5_39;

  m4 = gnum4;

  global = callPackage ../development/tools/misc/global { };

  gnome_doc_utils = callPackage ../development/tools/documentation/gnome-doc-utils {};

  gnum4 = callPackage ../development/tools/misc/gnum4 { };

  gnumake380 = callPackage ../development/tools/build-managers/gnumake/3.80 { };
  gnumake381 = callPackage ../development/tools/build-managers/gnumake/3.81 { };
  gnumake382 = callPackage ../development/tools/build-managers/gnumake/3.82 { };
  gnumake40  = callPackage ../development/tools/build-managers/gnumake/4.0  { };
  gnumake = gnumake382;

  gob2 = callPackage ../development/tools/misc/gob2 { };

  gradle = callPackage ../development/tools/build-managers/gradle { };

  gperf = callPackage ../development/tools/misc/gperf { };

  gtk_doc = callPackage ../development/tools/documentation/gtk-doc { };

  gtkdialog = callPackage ../development/tools/misc/gtkdialog { };

  guileLint = callPackage ../development/tools/guile/guile-lint { };

  gwrap = callPackage ../development/tools/guile/g-wrap { };

  help2man = callPackage ../development/tools/misc/help2man {
    inherit (perlPackages) LocaleGettext;
  };

  hyenae = callPackage ../tools/networking/hyenae { };

  ibus = callPackage ../development/libraries/ibus { };

  icmake = callPackage ../development/tools/build-managers/icmake { };

  iconnamingutils = callPackage ../development/tools/misc/icon-naming-utils {
    inherit (perlPackages) XMLSimple;
  };

  indent = callPackage ../development/tools/misc/indent { };

  ino = callPackage ../development/arduino/ino { };

  inotifyTools = callPackage ../development/tools/misc/inotify-tools { };

  intel-gpu-tools = callPackage ../development/tools/misc/intel-gpu-tools {
    inherit (xorg) libpciaccess dri2proto libX11 libXext libXv libXrandr;
  };

  ired = callPackage ../development/tools/analysis/radare/ired.nix { };

  itstool = callPackage ../development/tools/misc/itstool { };

  jam = callPackage ../development/tools/build-managers/jam { };

  jikespg = callPackage ../development/tools/parsing/jikespg { };

  jenkins = callPackage ../development/tools/continuous-integration/jenkins { };

  lcov = callPackage ../development/tools/analysis/lcov { };

  leiningen = callPackage ../development/tools/build-managers/leiningen { };

  libtool = libtool_2;

  libtool_1_5 = callPackage ../development/tools/misc/libtool { };

  libtool_2 = callPackage ../development/tools/misc/libtool/libtool2.nix { };

  lsof = callPackage ../development/tools/misc/lsof { };

  ltrace = callPackage ../development/tools/misc/ltrace { };

  lttng-tools = callPackage ../development/tools/misc/lttng-tools { };

  lttng-ust = callPackage ../development/tools/misc/lttng-ust { };

  lttv = callPackage ../development/tools/misc/lttv { };

  maven = maven3;
  maven3 = callPackage ../development/tools/build-managers/apache-maven { jdk = openjdk; };

  mk = callPackage ../development/tools/build-managers/mk { };

  neoload = callPackage ../development/tools/neoload {
    licenseAccepted = (config.neoload.accept_license or false);
    fontsConf = makeFontsConf {
      fontDirectories = [
        xorg.fontbhttf
      ];
    };
  };

  ninja = callPackage ../development/tools/build-managers/ninja { };

  nixbang = callPackage ../development/tools/misc/nixbang {
      pythonPackages = python3Packages;
  };

  node_webkit = callPackage ../development/tools/node-webkit {
    gconf = pkgs.gnome.GConf;
  };

  noweb = callPackage ../development/tools/literate-programming/noweb { };

  omake = callPackage ../development/tools/ocaml/omake { };
  omake_rc1 = callPackage ../development/tools/ocaml/omake/0.9.8.6-rc1.nix { };

  opengrok = callPackage ../development/tools/misc/opengrok { };

  openocd = callPackage ../development/tools/misc/openocd { };

  oprofile = callPackage ../development/tools/profiling/oprofile { };

  patchelf = callPackage ../development/tools/misc/patchelf { };

  peg = callPackage ../development/tools/parsing/peg { };

  phantomjs = callPackage ../development/tools/phantomjs {
    stdenv = if stdenv.isDarwin
      then overrideGCC stdenv gccApple
      else stdenv;
  };

  pmccabe = callPackage ../development/tools/misc/pmccabe { };

  /* Make pkgconfig always return a nativeDrv, never a proper crossDrv,
     because most usage of pkgconfig as buildInput (inheritance of
     pre-cross nixpkgs) means using it using as nativeBuildInput
     cross_renaming: we should make all programs use pkgconfig as
     nativeBuildInput after the renaming.
     */
  pkgconfig = forceNativeDrv (callPackage ../development/tools/misc/pkgconfig { });
  pkgconfigUpstream = lowPrio (pkgconfig.override { vanilla = true; });

  prelink = callPackage ../development/tools/misc/prelink { };

  premake3 = callPackage ../development/tools/misc/premake/3.nix { };

  premake4 = callPackage ../development/tools/misc/premake { };

  premake = premake4;

  pstack = callPackage ../development/tools/misc/gdb/pstack.nix { };

  racerRust = callPackage ../development/tools/rust/racer { rust = rustcMaster; };

  radare = callPackage ../development/tools/analysis/radare {
    inherit (gnome) vte;
    lua = lua5;
    useX11 = config.radare.useX11 or false;
    pythonBindings = config.radare.pythonBindings or false;
    rubyBindings = config.radare.rubyBindings or false;
    luaBindings = config.radare.luaBindings or false;
  };
  radare2 = callPackage ../development/tools/analysis/radare2 {
    inherit (gnome) vte;
    lua = lua5;
    useX11 = config.radare.useX11 or false;
    pythonBindings = config.radare.pythonBindings or false;
    rubyBindings = config.radare.rubyBindings or false;
    luaBindings = config.radare.luaBindings or false;
  };


  ragel = callPackage ../development/tools/parsing/ragel { };

  hammer = callPackage ../development/tools/parsing/hammer { };

  re2c = callPackage ../development/tools/parsing/re2c { };

  remake = callPackage ../development/tools/build-managers/remake { };

  saleae-logic = callPackage ../development/tools/misc/saleae-logic { };

  # couldn't find the source yet
  seleniumRCBin = callPackage ../development/tools/selenium/remote-control {
    jre = jdk;
  };

  selenium-server-standalone = callPackage ../development/tools/selenium/server { };

  selendroid = callPackage ../development/tools/selenium/selendroid { };

  scons = callPackage ../development/tools/build-managers/scons { };

  sbt = callPackage ../development/tools/build-managers/sbt { };
  simpleBuildTool = sbt;

  sigrok-cli = callPackage ../development/tools/sigrok-cli { };

  simpleTpmPk11 = callPackage ../tools/security/simple-tpm-pk11 { };

  slimerjs = callPackage ../development/tools/slimerjs {};

  sloccount = callPackage ../development/tools/misc/sloccount { };

  smatch = callPackage ../development/tools/analysis/smatch {
    buildllvmsparse = false;
    buildc2xml = false;
  };

  smc = callPackage ../tools/misc/smc { };

  sparse = callPackage ../development/tools/analysis/sparse { };

  speedtest_cli = callPackage ../tools/networking/speedtest-cli { };

  spin = callPackage ../development/tools/analysis/spin { };

  splint = callPackage ../development/tools/analysis/splint {
    flex = flex_2_5_35;
  };

  stm32flash = callPackage ../development/tools/misc/stm32flash { };

  strace = callPackage ../development/tools/misc/strace { };

  swig = callPackage ../development/tools/misc/swig { };

  swig2 = callPackage ../development/tools/misc/swig/2.x.nix { };

  swig3 = callPackage ../development/tools/misc/swig/3.x.nix { };

  swigWithJava = swig;

  swfmill = callPackage ../tools/video/swfmill { };

  swftools = callPackage ../tools/video/swftools { };

  tcptrack = callPackage ../development/tools/misc/tcptrack { };

  teensy-loader = callPackage ../development/tools/misc/teensy { };

  texinfo413 = callPackage ../development/tools/misc/texinfo/4.13a.nix { };
  texinfo5 = callPackage ../development/tools/misc/texinfo/5.2.nix { };
  texinfo4 = texinfo413;
  texinfo = texinfo5;
  texinfoInteractive = appendToName "interactive" (
    texinfo.override { interactive = true; }
  );

  texi2html = callPackage ../development/tools/misc/texi2html { };

  uhd = callPackage ../development/tools/misc/uhd { };

  uisp = callPackage ../development/tools/misc/uisp { };

  uncrustify = callPackage ../development/tools/misc/uncrustify { };

  vagrant = callPackage ../development/tools/vagrant {
    ruby = ruby_2_0_0;
  };

  gdb = callPackage ../development/tools/misc/gdb {
    guile = null;
    hurd = gnu.hurdCross;
    inherit (gnu) mig;
  };

  gdbGuile = lowPrio (gdb.override { inherit guile; });

  gdbCross = lowPrio (callPackage ../development/tools/misc/gdb {
    target = crossSystem;
  });

  valgrind = callPackage ../development/tools/analysis/valgrind {
    stdenv =
      # On Darwin, Valgrind 3.7.0 expects Apple's GCC (for
      # `__private_extern'.)
      if stdenv.isDarwin
      then overrideGCC stdenv gccApple
      else stdenv;
  };

  valkyrie = callPackage ../development/tools/analysis/valkyrie { };

  xc3sprog = callPackage ../development/tools/misc/xc3sprog { };

  xmlindent = callPackage ../development/web/xmlindent {};

  xpwn = callPackage ../development/mobile/xpwn {};

  xxdiff = callPackage ../development/tools/misc/xxdiff {
    bison = bison2;
  };

  yacc = bison;

  yodl = callPackage ../development/tools/misc/yodl { };

  winpdb = callPackage ../development/tools/winpdb { };


  ### DEVELOPMENT / LIBRARIES

  a52dec = callPackage ../development/libraries/a52dec { };

  aacskeys = callPackage ../development/libraries/aacskeys { };

  aalib = callPackage ../development/libraries/aalib { };

  accountsservice = callPackage ../development/libraries/accountsservice { };

  acl = callPackage ../development/libraries/acl { };

  activemq = callPackage ../development/libraries/apache-activemq { };

  adns = callPackage ../development/libraries/adns { };

  afflib = callPackage ../development/libraries/afflib {
    automake = automake114x;
  };

  agg = callPackage ../development/libraries/agg { };

  allegro = callPackage ../development/libraries/allegro {};
  allegro5 = callPackage ../development/libraries/allegro/5.nix {};
  allegro5unstable = callPackage
    ../development/libraries/allegro/5-unstable.nix {};

  amrnb = callPackage ../development/libraries/amrnb { };

  amrwb = callPackage ../development/libraries/amrwb { };

  apr = callPackage ../development/libraries/apr { };

  aprutil = callPackage ../development/libraries/apr-util {
    bdbSupport = true;
  };

  assimp = callPackage ../development/libraries/assimp { };

  asio = callPackage ../development/libraries/asio { };

  aspell = callPackage ../development/libraries/aspell { };

  aspellDicts = recurseIntoAttrs (import ../development/libraries/aspell/dictionaries.nix {
    inherit fetchurl stdenv aspell which;
  });

  aterm = aterm25;

  aterm25 = callPackage ../development/libraries/aterm/2.5.nix { };

  aterm28 = lowPrio (callPackage ../development/libraries/aterm/2.8.nix { });

  attica = callPackage ../development/libraries/attica { };

  attr = callPackage ../development/libraries/attr { };

  at_spi2_core = callPackage ../development/libraries/at-spi2-core { };

  at_spi2_atk = callPackage ../development/libraries/at-spi2-atk { };

  aqbanking = callPackage ../development/libraries/aqbanking { };

  aubio = callPackage ../development/libraries/aubio { };

  audiofile = callPackage ../development/libraries/audiofile { };

  babl = callPackage ../development/libraries/babl { };

  beecrypt = callPackage ../development/libraries/beecrypt { };

  boehmgc = callPackage ../development/libraries/boehm-gc { };

  boolstuff = callPackage ../development/libraries/boolstuff { };

  boost155 = callPackage ../development/libraries/boost/1.55.nix { };
  boost156 = callPackage ../development/libraries/boost/1.56.nix { };
  boost157 = callPackage ../development/libraries/boost/1.57.nix { };
  boost = boost156;

  boost_process = callPackage ../development/libraries/boost-process { };

  botan = callPackage ../development/libraries/botan { };
  botanUnstable = callPackage ../development/libraries/botan/unstable.nix { };

  box2d = callPackage ../development/libraries/box2d { };
  box2d_2_0_1 = callPackage ../development/libraries/box2d/2.0.1.nix { };

  buddy = callPackage ../development/libraries/buddy { };

  bwidget = callPackage ../development/libraries/bwidget { };

  c-ares = callPackage ../development/libraries/c-ares {
    fetchurl = fetchurlBoot;
  };

  caelum = callPackage ../development/libraries/caelum { };

  capnproto = callPackage ../development/libraries/capnproto { };

  ccnx = callPackage ../development/libraries/ccnx { };

  ndn-cxx = callPackage ../development/libraries/ndn-cxx { };

  cimg = callPackage  ../development/libraries/cimg { };

  scmccid = callPackage ../development/libraries/scmccid { };

  ccrtp = callPackage ../development/libraries/ccrtp { };
  ccrtp_1_8 = callPackage ../development/libraries/ccrtp/1.8.nix { };

  celt = callPackage ../development/libraries/celt {};
  celt_0_7 = callPackage ../development/libraries/celt/0.7.nix {};
  celt_0_5_1 = callPackage ../development/libraries/celt/0.5.1.nix {};

  cgal = callPackage ../development/libraries/CGAL {};

  cgui = callPackage ../development/libraries/cgui {};

  check = callPackage ../development/libraries/check { };

  chipmunk = builderDefsPackage (import ../development/libraries/chipmunk) {
    inherit cmake freeglut mesa;
    inherit (xlibs) libX11 xproto inputproto libXi libXmu;
  };

  chmlib = callPackage ../development/libraries/chmlib { };

  chromaprint = callPackage ../development/libraries/chromaprint { };

  cilaterm = callPackage ../development/libraries/cil-aterm {
    stdenv = overrideInStdenv stdenv [gnumake380];
  };

  clanlib = callPackage ../development/libraries/clanlib { };

  classads = callPackage ../development/libraries/classads { };

  classpath = callPackage ../development/libraries/java/classpath {
    javac = gcj;
    jvm = gcj;
    gconf = gnome.GConf;
  };

  clearsilver = callPackage ../development/libraries/clearsilver { };

  cln = callPackage ../development/libraries/cln { };

  clppcre = builderDefsPackage (import ../development/libraries/cl-ppcre) { };

  clucene_core_2 = callPackage ../development/libraries/clucene-core/2.x.nix { };

  clucene_core_1 = callPackage ../development/libraries/clucene-core { };

  clucene_core = clucene_core_1;

  clutter = callPackage ../development/libraries/clutter { };

  clutter_1_18 = callPackage ../development/libraries/clutter/1.18.nix {
    cogl = cogl_1_18;
  };

  clutter-gst = callPackage ../development/libraries/clutter-gst { };

  clutter_gtk = callPackage ../development/libraries/clutter-gtk { };
  clutter_gtk_0_10 = callPackage ../development/libraries/clutter-gtk/0.10.8.nix { };

  cminpack = callPackage ../development/libraries/cminpack { };

  cogl = callPackage ../development/libraries/cogl { };

  cogl_1_18 = callPackage ../development/libraries/cogl/1.18.nix { };

  coin3d = callPackage ../development/libraries/coin3d { };

  commoncpp2 = callPackage ../development/libraries/commoncpp2 { };

  confuse = callPackage ../development/libraries/confuse { };

  coredumper = callPackage ../development/libraries/coredumper { };

  ctl = dropCxx (callPackage ../development/libraries/ctl { });

  cpp-netlib = callPackage ../development/libraries/cpp-netlib { };

  cppunit = callPackage ../development/libraries/cppunit { };

  cppnetlib = callPackage ../development/libraries/cppnetlib { };

  cracklib = callPackage ../development/libraries/cracklib { };

  cryptopp = callPackage ../development/libraries/crypto++ { };

  cyrus_sasl = callPackage ../development/libraries/cyrus-sasl { };

  # Make bdb5 the default as it is the last release under the custom
  # bsd-like license
  db = db5;
  db4 = db48;
  db44 = callPackage ../development/libraries/db/db-4.4.nix { };
  db45 = callPackage ../development/libraries/db/db-4.5.nix { };
  db47 = callPackage ../development/libraries/db/db-4.7.nix { };
  db48 = callPackage ../development/libraries/db/db-4.8.nix { };
  db5 = db53;
  db53 = callPackage ../development/libraries/db/db-5.3.nix { };
  db6 = db60;
  db60 = callPackage ../development/libraries/db/db-6.0.nix { };

  dbus = callPackage ../development/libraries/dbus { };
  dbus_cplusplus  = callPackage ../development/libraries/dbus-cplusplus { };
  dbus_glib       = callPackage ../development/libraries/dbus-glib { };
  dbus_java       = callPackage ../development/libraries/java/dbus-java { };
  dbus_python     = callPackage ../development/python-modules/dbus {
    isPyPy = python.executable == "pypy";
  };

  # Should we deprecate these? Currently there are many references.
  dbus_tools = pkgs.dbus.tools;
  dbus_libs = pkgs.dbus.libs;
  dbus_daemon = pkgs.dbus.daemon;

  dhex = callPackage ../applications/editors/dhex { };

  double_conversion = callPackage ../development/libraries/double-conversion { };

  dclib = callPackage ../development/libraries/dclib { };

  dillo = callPackage ../applications/networking/browsers/dillo {
    fltk = fltk13;
  };

  directfb = callPackage ../development/libraries/directfb { };

  dlib = callPackage ../development/libraries/dlib { };

  dotconf = callPackage ../development/libraries/dotconf { };

  dssi = callPackage ../development/libraries/dssi {};

  dragonegg = llvmPackages.dragonegg;

  dxflib = callPackage ../development/libraries/dxflib {};

  eigen = callPackage ../development/libraries/eigen {};

  eigen2 = callPackage ../development/libraries/eigen/2.0.nix {};

  enchant = callPackage ../development/libraries/enchant { };

  enet = callPackage ../development/libraries/enet { };

  enginepkcs11 = callPackage ../development/libraries/enginepkcs11 { };

  epoxy = callPackage ../development/libraries/epoxy {
    inherit (xorg) utilmacros libX11;
  };

  esdl = callPackage ../development/libraries/esdl { };

  exiv2 = callPackage ../development/libraries/exiv2 { };

  expat = callPackage ../development/libraries/expat { };

  extremetuxracer = callPackage ../games/extremetuxracer {
    libpng = libpng12;
  };

  eventlog = callPackage ../development/libraries/eventlog { };

  facile = callPackage ../development/libraries/facile { };

  faac = callPackage ../development/libraries/faac { };

  faad2 = callPackage ../development/libraries/faad2 { };

  farsight2 = callPackage ../development/libraries/farsight2 { };

  farstream = callPackage ../development/libraries/farstream {
    inherit (gst_all_1)
      gstreamer gst-plugins-base gst-python gst-plugins-good gst-plugins-bad
      gst-libav;
  };

  fcgi = callPackage ../development/libraries/fcgi { };

  ffmpeg_0_6 = callPackage ../development/libraries/ffmpeg/0.6.nix {
    vpxSupport = !stdenv.isMips;
  };

  ffmpeg_0_6_90 = callPackage ../development/libraries/ffmpeg/0.6.90.nix {
    vpxSupport = !stdenv.isMips;
  };

  ffmpeg_0_10 = callPackage ../development/libraries/ffmpeg/0.10.nix {
    vpxSupport = !stdenv.isMips;

    stdenv = if stdenv.isDarwin
      then overrideGCC stdenv gccApple
      else stdenv;
  };

  ffmpeg_1 = callPackage ../development/libraries/ffmpeg/1.x.nix {
    vpxSupport = !stdenv.isMips;
  };

  ffmpeg_2_3 = callPackage ../development/libraries/ffmpeg/2.3.x.nix { };

  ffmpeg_2 = callPackage ../development/libraries/ffmpeg/2.x.nix { };

  ffmpeg = ffmpeg_2;

  ffms = callPackage ../development/libraries/ffms { };

  fftw = callPackage ../development/libraries/fftw { };
  fftwSinglePrec = fftw.override { precision = "single"; };
  fftwFloat = fftwSinglePrec; # the configure option is just an alias

  fish-fillets-ng = callPackage ../games/fish-fillets-ng {};

  flann = callPackage ../development/libraries/flann { };

  flite = callPackage ../development/libraries/flite { };

  fltk13 = callPackage ../development/libraries/fltk/fltk13.nix { };

  fltk20 = callPackage ../development/libraries/fltk { };

  fmod = callPackage ../development/libraries/fmod { };

  freeimage = callPackage ../development/libraries/freeimage { };

  freetts = callPackage ../development/libraries/freetts { };

  cfitsio = callPackage ../development/libraries/cfitsio { };

  fontconfig_210 = callPackage ../development/libraries/fontconfig/2.10.nix { };

  fontconfig = callPackage ../development/libraries/fontconfig { };

  folly = callPackage ../development/libraries/folly { };

  makeFontsConf = let fontconfig_ = fontconfig; in {fontconfig ? fontconfig_, fontDirectories}:
    import ../development/libraries/fontconfig/make-fonts-conf.nix {
      inherit runCommand libxslt fontconfig fontDirectories;
      inherit (xorg) fontbhttf;
    };

  freealut = callPackage ../development/libraries/freealut { };

  freeglut = callPackage ../development/libraries/freeglut { };

  freetype = callPackage ../development/libraries/freetype { };

  frei0r = callPackage ../development/libraries/frei0r { };

  fribidi = callPackage ../development/libraries/fribidi { };

  funambol = callPackage ../development/libraries/funambol { };

  fam = gamin;

  gamin = callPackage ../development/libraries/gamin { };

  ganv = callPackage ../development/libraries/ganv { };

  gav = callPackage ../games/gav { };

  gsb = callPackage ../games/gsb { };

  gdome2 = callPackage ../development/libraries/gdome2 {
    inherit (gnome) gtkdoc;
  };

  gdbm = callPackage ../development/libraries/gdbm { };

  gecode = callPackage ../development/libraries/gecode { };

  gegl = callPackage ../development/libraries/gegl { };

  geoclue = callPackage ../development/libraries/geoclue {};

  geoclue2 = callPackage ../development/libraries/geoclue/2.0.nix {};

  geoip = callPackage ../development/libraries/geoip { };

  geoipjava = callPackage ../development/libraries/java/geoipjava { };

  geos = callPackage ../development/libraries/geos { };

  getdata = callPackage ../development/libraries/getdata { };

  gettext = gettext_0_18;

  gettext_0_17 = callPackage ../development/libraries/gettext/0.17.nix { };
  gettext_0_18 = callPackage ../development/libraries/gettext { };

  gd = callPackage ../development/libraries/gd { };

  gdal = callPackage ../development/libraries/gdal { };

  gdcm = callPackage ../development/libraries/gdcm { };

  ggz_base_libs = callPackage ../development/libraries/ggz_base_libs {};

  giblib = callPackage ../development/libraries/giblib { };

  libgit2 = callPackage ../development/libraries/git2 { };

  glew = callPackage ../development/libraries/glew { };

  glfw = glfw3;
  glfw2 = callPackage ../development/libraries/glfw/2.x.nix { };
  glfw3 = callPackage ../development/libraries/glfw/3.x.nix { };

  glibc = callPackage ../development/libraries/glibc/2.19 {
    kernelHeaders = linuxHeaders;
    installLocales = config.glibc.locales or false;
    machHeaders = null;
    hurdHeaders = null;
    gccCross = null;
  };

  glibc_memusage = callPackage ../development/libraries/glibc/2.19 {
    kernelHeaders = linuxHeaders;
    installLocales = false;
    withGd = true;
  };

  glibcCross = forceNativeDrv (makeOverridable (import ../development/libraries/glibc/2.19)
    (let crossGNU = crossSystem != null && crossSystem.config == "i586-pc-gnu";
     in {
       inherit stdenv fetchurl;
       gccCross = gccCrossStageStatic;
       kernelHeaders = if crossGNU then gnu.hurdHeaders else linuxHeadersCross;
       installLocales = config.glibc.locales or false;
     }
     // lib.optionalAttrs crossGNU {
        inherit (gnu) machHeaders hurdHeaders libpthreadHeaders mig;
        inherit fetchgit;
      }));


  # We can choose:
  libcCrossChooser = name : if name == "glibc" then glibcCross
    else if name == "uclibc" then uclibcCross
    else if name == "msvcrt" then windows.mingw_w64
    else if name == "libSystem" then darwin.xcode
    else throw "Unknown libc";

  libcCross = assert crossSystem != null; libcCrossChooser crossSystem.libc;

  eglibc = callPackage ../development/libraries/eglibc {
    kernelHeaders = linuxHeaders;
    installLocales = config.glibc.locales or false;
  };

  glibcLocales = callPackage ../development/libraries/glibc/2.19/locales.nix { };

  glibcInfo = callPackage ../development/libraries/glibc/2.19/info.nix { };

  glibc_multi = callPackage ../development/libraries/glibc/2.19/multi.nix {
    inherit glibc;
    glibc32 = (import ./all-packages.nix {system = "i686-linux";}).glibc;
  };

  glm = callPackage ../development/libraries/glm { };

  glog = callPackage ../development/libraries/glog { };

  gloox = callPackage ../development/libraries/gloox { };

  glpk = callPackage ../development/libraries/glpk { };

  glsurf = callPackage ../applications/science/math/glsurf {
    inherit (ocamlPackages) lablgl findlib ocaml_mysql mlgmp;
    libpng = libpng12;
    giflib = giflib_4_1;
    camlimages = ocamlPackages.camlimages_4_0;
  };

  gmime = callPackage ../development/libraries/gmime { };

  gmm = callPackage ../development/libraries/gmm { };

  gmp = gmp5;
  gmp5 = gmp51;

  gmpxx = appendToName "with-cxx" (gmp.override { cxx = true; });

  # The GHC bootstrap binaries link against libgmp.so.3, which is in GMP 4.x.
  gmp4 = callPackage ../development/libraries/gmp/4.3.2.nix { };

  gmp51 = callPackage ../development/libraries/gmp/5.1.x.nix { };

  #GMP ex-satellite, so better keep it near gmp
  mpfr = callPackage ../development/libraries/mpfr/default.nix { };

  gobjectIntrospection = callPackage ../development/libraries/gobject-introspection { };

  goocanvas = callPackage ../development/libraries/goocanvas { };

  google-gflags = callPackage ../development/libraries/google-gflags { };

  gperftools = callPackage ../development/libraries/gperftools { };

  gst_all_1 = recurseIntoAttrs(callPackage ../development/libraries/gstreamer {
    callPackage = pkgs.newScope (pkgs // { inherit (pkgs) libav; });
  });

  gst_all = {
    inherit (pkgs) gstreamer gnonlin gst_python qt_gstreamer;
    gstPluginsBase = pkgs.gst_plugins_base;
    gstPluginsBad = pkgs.gst_plugins_bad;
    gstPluginsGood = pkgs.gst_plugins_good;
    gstPluginsUgly = pkgs.gst_plugins_ugly;
    gstFfmpeg = pkgs.gst_ffmpeg;
  };

  gstreamer = callPackage ../development/libraries/gstreamer/legacy/gstreamer {
    bison = bison2;
  };

  gst_plugins_base = callPackage ../development/libraries/gstreamer/legacy/gst-plugins-base {};

  gst_plugins_good = callPackage ../development/libraries/gstreamer/legacy/gst-plugins-good {};

  gst_plugins_bad = callPackage ../development/libraries/gstreamer/legacy/gst-plugins-bad {};

  gst_plugins_ugly = callPackage ../development/libraries/gstreamer/legacy/gst-plugins-ugly {};

  gst_ffmpeg = callPackage ../development/libraries/gstreamer/legacy/gst-ffmpeg {
    ffmpeg = ffmpeg_0_10;
  };

  gst_python = callPackage ../development/libraries/gstreamer/legacy/gst-python {};

  gstreamermm = callPackage ../development/libraries/gstreamer/legacy/gstreamermm { };

  gnonlin = callPackage ../development/libraries/gstreamer/legacy/gnonlin {};

  gusb = callPackage ../development/libraries/gusb {
    inherit (gnome) gtkdoc;
  };

  qt_gstreamer = callPackage ../development/libraries/gstreamer/legacy/qt-gstreamer {};

  qt_gstreamer1 = callPackage ../development/libraries/gstreamer/qt-gstreamer {};

  gnet = callPackage ../development/libraries/gnet { };

  gnu-efi = callPackage ../development/libraries/gnu-efi { };

  gnutls = gnutls32;

  gnutls31 = callPackage ../development/libraries/gnutls/3.1.nix {
    guileBindings = config.gnutls.guile or false;
  };

  gnutls32 = callPackage ../development/libraries/gnutls/3.2.nix {
    guileBindings = config.gnutls.guile or false;
  };

  gnutls_with_guile = lowPrio (gnutls.override { guileBindings = true; });

  gpac = callPackage ../applications/video/gpac { };

  gpgme = callPackage ../development/libraries/gpgme {
    gnupg1 = gnupg1orig;
  };

  grantlee = callPackage ../development/libraries/grantlee { };

  gsasl = callPackage ../development/libraries/gsasl { };

  gsl = callPackage ../development/libraries/gsl { };

  gsm = callPackage ../development/libraries/gsm {};

  gsoap = callPackage ../development/libraries/gsoap { };

  gss = callPackage ../development/libraries/gss { };

  gtkimageview = callPackage ../development/libraries/gtkimageview { };

  gtkmathview = callPackage ../development/libraries/gtkmathview { };

  gtkLibs = {
    inherit (pkgs) glib glibmm atk atkmm cairo pango pangomm gdk_pixbuf gtk
      gtkmm;
  };

  glib = callPackage ../development/libraries/glib { };
  glib-tested = glib.override { doCheck = true; }; # checked version separate to break cycles
  glibmm = callPackage ../development/libraries/glibmm { };

  glib_networking = callPackage ../development/libraries/glib-networking {};

  atk = callPackage ../development/libraries/atk { };
  atkmm = callPackage ../development/libraries/atkmm { };

  pixman = callPackage ../development/libraries/pixman { };

  cairo = callPackage ../development/libraries/cairo {
    glSupport = config.cairo.gl or (stdenv.isLinux &&
      !stdenv.isArm && !stdenv.isMips);
  };
  cairomm = callPackage ../development/libraries/cairomm { };

  pango = callPackage ../development/libraries/pango { };
  pangomm = callPackage ../development/libraries/pangomm { };

  pangox_compat = callPackage ../development/libraries/pangox-compat { };

  gdk_pixbuf = callPackage ../development/libraries/gdk-pixbuf {
    # workaround signal 10 in gdk_pixbuf tests
    stdenv = if stdenv.isDarwin
      then clangStdenv
      else stdenv;
  };

  granite = callPackage ../development/libraries/granite { };

  gtk2 = callPackage ../development/libraries/gtk+/2.x.nix {
    cupsSupport = config.gtk2.cups or stdenv.isLinux;
  };

  gtk3 = callPackage ../development/libraries/gtk+/3.x.nix { };

  gtk = pkgs.gtk2;

  gtkmm = callPackage ../development/libraries/gtkmm/2.x.nix { };
  gtkmm3 = callPackage ../development/libraries/gtkmm/3.x.nix { };

  gtkmozembedsharp = callPackage ../development/libraries/gtkmozembed-sharp {
    gtksharp = gtksharp2;
  };

  gtksharp1 = callPackage ../development/libraries/gtk-sharp-1 {
    inherit (gnome) libglade libgtkhtml gtkhtml
              libgnomecanvas libgnomeui libgnomeprint
              libgnomeprintui GConf;
  };

  gtksharp2 = callPackage ../development/libraries/gtk-sharp-2 {
    inherit (gnome) libglade libgtkhtml gtkhtml
              libgnomecanvas libgnomeui libgnomeprint
              libgnomeprintui GConf gnomepanel;
  };

  gtksourceviewsharp = callPackage ../development/libraries/gtksourceview-sharp {
    inherit (gnome) gtksourceview;
    gtksharp = gtksharp2;
  };

  gtkspell = callPackage ../development/libraries/gtkspell { };

  gtkspell3 = callPackage ../development/libraries/gtkspell/3.nix { };

  gtkspellmm = callPackage ../development/libraries/gtkspellmm { };

  gts = callPackage ../development/libraries/gts { };

  gvfs = callPackage ../development/libraries/gvfs { gconf = gnome.GConf; };

  gwenhywfar = callPackage ../development/libraries/gwenhywfar { };

  hamlib = callPackage ../development/libraries/hamlib { };

  # TODO : Add MIT Kerberos and let admin choose.
  kerberos = heimdal;

  heimdal = callPackage ../development/libraries/kerberos/heimdal.nix { };

  harfbuzz = callPackage ../development/libraries/harfbuzz { };
  harfbuzz-icu = callPackage ../development/libraries/harfbuzz {
    withIcu = true;
    withGraphite2 = true;
  };

  hawknl = callPackage ../development/libraries/hawknl { };

  herqq = callPackage ../development/libraries/herqq { };

  hidapi = callPackage ../development/libraries/hidapi {
    libusb = libusb1;
  };

  hivex = callPackage ../development/libraries/hivex {
    inherit (perlPackages) IOStringy;
  };

  hspell = callPackage ../development/libraries/hspell { };

  hspellDicts = callPackage ../development/libraries/hspell/dicts.nix { };

  hsqldb = callPackage ../development/libraries/java/hsqldb { };

  http-parser = callPackage ../development/libraries/http-parser { inherit (pythonPackages) gyp; };

  hunspell = callPackage ../development/libraries/hunspell { };

  hwloc = callPackage ../development/libraries/hwloc {
    inherit (xlibs) libX11;
  };

  hydraAntLogger = callPackage ../development/libraries/java/hydra-ant-logger { };

  icu = callPackage ../development/libraries/icu { };

  id3lib = callPackage ../development/libraries/id3lib { };

  iksemel = callPackage ../development/libraries/iksemel { };

  ilbc = callPackage ../development/libraries/ilbc { };

  ilixi = callPackage ../development/libraries/ilixi { };

  ilmbase = dropCxx (callPackage ../development/libraries/ilmbase { });

  imlib = callPackage ../development/libraries/imlib {
    libpng = libpng12;
  };

  imlib2 = callPackage ../development/libraries/imlib2 { };

  ijs = callPackage ../development/libraries/ijs { };

  incrtcl = callPackage ../development/libraries/incrtcl { };

  indilib = callPackage ../development/libraries/indilib { };

  indilib_0_9_9 = callPackage ../development/libraries/indilib/0_9_9.nix { };

  iniparser = callPackage ../development/libraries/iniparser { };

  intltool = callPackage ../development/tools/misc/intltool { };

  irrlicht3843 = callPackage ../development/libraries/irrlicht { };

  isocodes = callPackage ../development/libraries/iso-codes { };

  itk = callPackage ../development/libraries/itk { };

  jamp = builderDefsPackage ../games/jamp {
    inherit mesa SDL SDL_image SDL_mixer;
  };

  jasper = callPackage ../development/libraries/jasper { };

  jama = callPackage ../development/libraries/jama { };

  jansson = callPackage ../development/libraries/jansson { };

  jbig2dec = callPackage ../development/libraries/jbig2dec { };

  jetty_gwt = callPackage ../development/libraries/java/jetty-gwt { };

  jetty_util = callPackage ../development/libraries/java/jetty-util { };

  json_glib = callPackage ../development/libraries/json-glib { };

  json-c-0-11 = callPackage ../development/libraries/json-c/0.11.nix { }; # vulnerable
  json_c = callPackage ../development/libraries/json-c { };

  jsoncpp = callPackage ../development/libraries/jsoncpp { };

  libjson = callPackage ../development/libraries/libjson { };

  judy = callPackage ../development/libraries/judy { };

  keybinder = callPackage ../development/libraries/keybinder {
    automake = automake111x;
    lua = lua5_1;
  };

  keybinder3 = callPackage ../development/libraries/keybinder3 {
    automake = automake111x;
  };

  krb5 = callPackage ../development/libraries/kerberos/krb5.nix { };

  LASzip = callPackage ../development/libraries/LASzip { };

  lcms = lcms1;

  lcms1 = callPackage ../development/libraries/lcms { };

  lcms2 = callPackage ../development/libraries/lcms2 { };

  ldb = callPackage ../development/libraries/ldb {
    sasl = cyrus_sasl;
    libgcrypt = libgcrypt_1_6;
  };

  lensfun = callPackage ../development/libraries/lensfun { };

  lesstif = callPackage ../development/libraries/lesstif { };

  lesstif93 = callPackage ../development/libraries/lesstif-0.93 { };

  leveldb = callPackage ../development/libraries/leveldb { };

  levmar = callPackage ../development/libraries/levmar { };

  leptonica = callPackage ../development/libraries/leptonica {
    libpng = libpng12;
  };

  lgi = callPackage ../development/libraries/lgi { };

  lib3ds = callPackage ../development/libraries/lib3ds { };

  libaacs = callPackage ../development/libraries/libaacs { };

  libaal = callPackage ../development/libraries/libaal { };

  libao = callPackage ../development/libraries/libao {
    usePulseAudio = config.pulseaudio or true;
  };

  libantlr3c = callPackage ../development/libraries/libantlr3c {};

  libarchive = callPackage ../development/libraries/libarchive { };

  libass = callPackage ../development/libraries/libass { };

  libassuan1 = callPackage ../development/libraries/libassuan1 { };

  libassuan = callPackage ../development/libraries/libassuan { };

  libassuan2_1 = callPackage ../development/libraries/libassuan/git.nix { };

  libatomic_ops = callPackage ../development/libraries/libatomic_ops {};

  libav = libav_11; # branch 11 is API-compatible with branch 10
  libav_all = callPackage ../development/libraries/libav { };
  inherit (libav_all) libav_0_8 libav_9 libav_11;

  libavc1394 = callPackage ../development/libraries/libavc1394 { };

  libbluedevil = callPackage ../development/libraries/libbluedevil { };

  libbluray = callPackage ../development/libraries/libbluray { };

  libbs2b = callPackage ../development/libraries/audio/libbs2b { };

  libcaca = callPackage ../development/libraries/libcaca { };

  libcanberra = callPackage ../development/libraries/libcanberra { };
  libcanberra_gtk3 = libcanberra.override { gtk = gtk3; };
  libcanberra_kde = if (config.kde_runtime.libcanberraWithoutGTK or true)
    then libcanberra.override { gtk = null; }
    else libcanberra;

  libcec = callPackage ../development/libraries/libcec { };

  libcello = callPackage ../development/libraries/libcello {};

  libcdaudio = callPackage ../development/libraries/libcdaudio { };

  libcddb = callPackage ../development/libraries/libcddb { };

  libcdio = callPackage ../development/libraries/libcdio { };
  libcdio082 = callPackage ../development/libraries/libcdio/0.82.nix { };

  libcdr = callPackage ../development/libraries/libcdr { lcms = lcms2; };

  libchamplain = callPackage ../development/libraries/libchamplain {
    inherit (gnome) libsoup;
  };

  libchardet = callPackage ../development/libraries/libchardet { };

  libchop = callPackage ../development/libraries/libchop { };

  libcm = callPackage ../development/libraries/libcm { };

  inherit (gnome3) libcroco;

  libcangjie = callPackage ../development/libraries/libcangjie { };

  libcredis = callPackage ../development/libraries/libcredis { };

  libctemplate = callPackage ../development/libraries/libctemplate { };

  libcouchbase = callPackage ../development/libraries/libcouchbase { };

  libcue = callPackage ../development/libraries/libcue { };

  libdaemon = callPackage ../development/libraries/libdaemon { };

  libdbi = callPackage ../development/libraries/libdbi { };

  libdbiDriversBase = callPackage ../development/libraries/libdbi-drivers {
    mysql = null;
    sqlite = null;
  };

  libdbiDrivers = libdbiDriversBase.override {
    inherit sqlite mysql;
  };

  libdbusmenu_qt = callPackage ../development/libraries/libdbusmenu-qt { };

  libdc1394 = callPackage ../development/libraries/libdc1394 { };

  libdc1394avt = callPackage ../development/libraries/libdc1394avt { };

  libdevil = dropCxx (callPackage ../development/libraries/libdevil { });

  libdiscid = callPackage ../development/libraries/libdiscid { };

  libdivsufsort = callPackage ../development/libraries/libdivsufsort { };

  libdmtx = callPackage ../development/libraries/libdmtx { };

  libdnet = callPackage ../development/libraries/libdnet { };

  libdrm = callPackage ../development/libraries/libdrm {
    inherit fetchurl stdenv pkgconfig;
    inherit (xorg) libpthreadstubs;
  };

  libdv = callPackage ../development/libraries/libdv { };

  libdvbpsi = callPackage ../development/libraries/libdvbpsi { };

  libdwg = callPackage ../development/libraries/libdwg { };

  libdvdcss = callPackage ../development/libraries/libdvdcss { };

  libdvdnav = callPackage ../development/libraries/libdvdnav { };

  libdvdread = callPackage ../development/libraries/libdvdread { };

  libdwarf = callPackage ../development/libraries/libdwarf { };

  libeatmydata = callPackage ../development/libraries/libeatmydata { };

  libebml = callPackage ../development/libraries/libebml { };

  libedit = callPackage ../development/libraries/libedit { };

  libelf = callPackage ../development/libraries/libelf { };

  libetpan = callPackage ../development/libraries/libetpan { };

  libfaketime = callPackage ../development/libraries/libfaketime { };

  libfakekey = callPackage ../development/libraries/libfakekey {
    inherit (xlibs) libX11 libXi xextproto;
  };

  libfm = callPackage ../development/libraries/libfm { };
  libfm-extra = callPackage ../development/libraries/libfm {
    extraOnly = true;
  };

  libgadu = callPackage ../development/libraries/libgadu { };

  libgdata = gnome3.libgdata;

  libgig = callPackage ../development/libraries/libgig { };

  libgnome_keyring = callPackage ../development/libraries/libgnome-keyring { };
  libgnome_keyring3 = gnome3.libgnome_keyring;

  libgnurl = callPackage ../development/libraries/libgnurl { };

  libseccomp = callPackage ../development/libraries/libseccomp { };

  libsecret = callPackage ../development/libraries/libsecret { };

  libserialport = callPackage ../development/libraries/libserialport { };

  libgtop = callPackage ../development/libraries/libgtop {};

  libLAS = callPackage ../development/libraries/libLAS { };

  liblo = callPackage ../development/libraries/liblo { };

  liblrdf = librdf;

  liblscp = callPackage ../development/libraries/liblscp { };

  libe-book = callPackage ../development/libraries/libe-book {};

  libechonest = callPackage ../development/libraries/libechonest { };

  libev = builderDefsPackage ../development/libraries/libev { };

  libevent14 = callPackage ../development/libraries/libevent/1.4.nix { };
  libevent = callPackage ../development/libraries/libevent { };

  libewf = callPackage ../development/libraries/libewf { };

  libexif = callPackage ../development/libraries/libexif { };

  libexosip = callPackage ../development/libraries/exosip {};

  libexosip_3 = callPackage ../development/libraries/exosip/3.x.nix {
    libosip = libosip_3;
  };

  libextractor = callPackage ../development/libraries/libextractor {
    libmpeg2 = mpeg2dec;
  };

  libexttextcat = callPackage ../development/libraries/libexttextcat {};

  libf2c = callPackage ../development/libraries/libf2c {};

  libfixposix = callPackage ../development/libraries/libfixposix {};

  libffcall = builderDefsPackage (import ../development/libraries/libffcall) {
    inherit fetchcvs;
  };

  libffi = callPackage ../development/libraries/libffi { };

  libfreefare = callPackage ../development/libraries/libfreefare { };

  libftdi = callPackage ../development/libraries/libftdi { };

  libftdi1 = callPackage ../development/libraries/libftdi/1.x.nix { };

  libgcrypt = callPackage ../development/libraries/libgcrypt { };

  libgcrypt_1_6 = lowPrio (callPackage ../development/libraries/libgcrypt/1.6.nix { });

  libgdiplus = callPackage ../development/libraries/libgdiplus { };

  libgksu = callPackage ../development/libraries/libgksu { };

  libgpgerror = callPackage ../development/libraries/libgpg-error { };

  libgphoto2 = callPackage ../development/libraries/libgphoto2 { };

  libgpod = callPackage ../development/libraries/libgpod {
    inherit (pkgs.pythonPackages) mutagen;
  };

  libgsystem = callPackage ../development/libraries/libgsystem { };

  libguestfs = callPackage ../development/libraries/libguestfs {
    inherit (perlPackages) libintlperl GetoptLong SysVirt;
  };

  libharu = callPackage ../development/libraries/libharu { };

  libHX = callPackage ../development/libraries/libHX { };

  libibmad = callPackage ../development/libraries/libibmad { };

  libibumad = callPackage ../development/libraries/libibumad { };

  libical = callPackage ../development/libraries/libical { };

  libicns = callPackage ../development/libraries/libicns { };

  libimobiledevice = callPackage ../development/libraries/libimobiledevice { };

  libiodbc = callPackage ../development/libraries/libiodbc {
    useGTK = config.libiodbc.gtk or false;
  };

  libivykis = callPackage ../development/libraries/libivykis { };

  liblastfmSF = callPackage ../development/libraries/liblastfmSF { };

  liblastfm = callPackage ../development/libraries/liblastfm { };

  liblqr1 = callPackage ../development/libraries/liblqr-1 { };

  liblockfile = callPackage ../development/libraries/liblockfile { };

  liblogging = callPackage ../development/libraries/liblogging { };

  libltc = callPackage ../development/libraries/libltc { };

  libmcrypt = callPackage ../development/libraries/libmcrypt {};

  libmhash = callPackage ../development/libraries/libmhash {};

  libmodbus = callPackage ../development/libraries/libmodbus {};

  libmtp = callPackage ../development/libraries/libmtp { };

  libmsgpack = callPackage ../development/libraries/libmsgpack { };

  libnatspec = callPackage ../development/libraries/libnatspec { };

  libndp = callPackage ../development/libraries/libndp { };

  libnfc = callPackage ../development/libraries/libnfc { };

  libnfsidmap = callPackage ../development/libraries/libnfsidmap { };

  libnice = callPackage ../development/libraries/libnice { };

  liboping = callPackage ../development/libraries/liboping { };

  libplist = callPackage ../development/libraries/libplist { };

  libQGLViewer = callPackage ../development/libraries/libqglviewer { };

  libre = callPackage ../development/libraries/libre {};
  librem = callPackage ../development/libraries/librem {};

  libresample = callPackage ../development/libraries/libresample {};

  librevenge = callPackage ../development/libraries/librevenge {};

  librevisa = callPackage ../development/libraries/librevisa { };

  libsamplerate = callPackage ../development/libraries/libsamplerate { };

  libsieve = callPackage ../development/libraries/libsieve { };

  libspectre = callPackage ../development/libraries/libspectre { };

  libgsf = callPackage ../development/libraries/libgsf { };

  libiconv = callPackage ../development/libraries/libiconv { };

  libiconvOrEmpty = if libiconvOrNull == null then [] else [libiconv];

  libiconvOrNull =
    if gcc.libc or null != null || stdenv.isGlibc
    then null
    else libiconv;

  # The logic behind this attribute is broken: libiconvOrNull==null does
  # NOT imply libiconv=glibc! On Darwin, for example, we have a native
  # libiconv library which is not glibc.
  libiconvOrLibc = if libiconvOrNull == null then gcc.libc else libiconv;

  # On non-GNU systems we need GNU Gettext for libintl.
  libintlOrEmpty = stdenv.lib.optional (!stdenv.isLinux) gettext;

  libid3tag = callPackage ../development/libraries/libid3tag { };

  libidn = callPackage ../development/libraries/libidn { };

  libiec61883 = callPackage ../development/libraries/libiec61883 { };

  libinfinity = callPackage ../development/libraries/libinfinity {
    inherit (gnome) gtkdoc;
  };

  libinput = callPackage ../development/libraries/libinput { };

  libiptcdata = callPackage ../development/libraries/libiptcdata { };

  libjpeg_original = callPackage ../development/libraries/libjpeg { };
  libjpeg_turbo = callPackage ../development/libraries/libjpeg-turbo { };
  libjpeg = if (stdenv.isLinux) then libjpeg_turbo else libjpeg_original; # some problems, both on FreeBSD and Darwin

  libjpeg62 = callPackage ../development/libraries/libjpeg/62.nix {
    libtool = libtool_1_5;
  };

  libjreen = callPackage ../development/libraries/libjreen { };

  libjson_rpc_cpp = callPackage ../development/libraries/libjson-rpc-cpp { };

  libkate = callPackage ../development/libraries/libkate { };

  libksba = callPackage ../development/libraries/libksba { };

  libmad = callPackage ../development/libraries/libmad { };

  libmatchbox = callPackage ../development/libraries/libmatchbox { };

  libmatthew_java = callPackage ../development/libraries/java/libmatthew-java { };

  libmatroska = callPackage ../development/libraries/libmatroska { };

  libmcs = callPackage ../development/libraries/libmcs { };

  libmemcached = callPackage ../development/libraries/libmemcached { };

  libmicrohttpd = callPackage ../development/libraries/libmicrohttpd { };

  libmikmod = callPackage ../development/libraries/libmikmod {
    # resolve the "stray '@' in program" errors
    stdenv = if stdenv.isDarwin
      then overrideGCC stdenv gccApple
      else stdenv;
  };

  libmilter = callPackage ../development/libraries/libmilter { };

  libmkv = callPackage ../development/libraries/libmkv { };

  libmms = callPackage ../development/libraries/libmms { };

  libmowgli = callPackage ../development/libraries/libmowgli { };

  libmng = callPackage ../development/libraries/libmng { };

  libmnl = callPackage ../development/libraries/libmnl { };

  libmodplug = callPackage ../development/libraries/libmodplug {};

  libmpcdec = callPackage ../development/libraries/libmpcdec { };

  libmp3splt = callPackage ../development/libraries/libmp3splt { };

  libmrss = callPackage ../development/libraries/libmrss { };

  libmsn = callPackage ../development/libraries/libmsn { };

  libmspack = callPackage ../development/libraries/libmspack { };

  libmusclecard = callPackage ../development/libraries/libmusclecard { };

  libmusicbrainz2 = callPackage ../development/libraries/libmusicbrainz/2.x.nix { };

  libmusicbrainz3 = callPackage ../development/libraries/libmusicbrainz { };

  libmusicbrainz5 = callPackage ../development/libraries/libmusicbrainz/5.x.nix { };

  libmusicbrainz = libmusicbrainz3;

  libmwaw = callPackage ../development/libraries/libmwaw { };

  libmx = callPackage ../development/libraries/libmx { };

  libnet = callPackage ../development/libraries/libnet { };

  libnetfilter_conntrack = callPackage ../development/libraries/libnetfilter_conntrack { };

  libnetfilter_cthelper = callPackage ../development/libraries/libnetfilter_cthelper { };

  libnetfilter_cttimeout = callPackage ../development/libraries/libnetfilter_cttimeout { };

  libnetfilter_queue = callPackage ../development/libraries/libnetfilter_queue { };

  libnfnetlink = callPackage ../development/libraries/libnfnetlink { };

  libnftnl = callPackage ../development/libraries/libnftnl { };

  libnih = callPackage ../development/libraries/libnih { };

  libnova = callPackage ../development/libraries/libnova { };

  libnxml = callPackage ../development/libraries/libnxml { };

  libodfgen = callPackage ../development/libraries/libodfgen { };

  libofa = callPackage ../development/libraries/libofa { };

  libofx = callPackage ../development/libraries/libofx { };

  libogg = callPackage ../development/libraries/libogg { };

  liboggz = callPackage ../development/libraries/liboggz { };

  liboil = callPackage ../development/libraries/liboil { };

  liboop = callPackage ../development/libraries/liboop { };

  libopus = callPackage ../development/libraries/libopus { };

  libosinfo = callPackage ../development/libraries/libosinfo {};

  libosip = callPackage ../development/libraries/osip {};

  libosip_3 = callPackage ../development/libraries/osip/3.nix {};

  libotr = callPackage ../development/libraries/libotr {
    libgcrypt = libgcrypt_1_6;
  };

  libotr_3_2 = callPackage ../development/libraries/libotr/3.2.nix { };

  libp11 = callPackage ../development/libraries/libp11 { };

  libpar2 = callPackage ../development/libraries/libpar2 { };

  libpcap = callPackage ../development/libraries/libpcap { };

  libpipeline = callPackage ../development/libraries/libpipeline { };

  libpng = callPackage ../development/libraries/libpng { };
  libpng_apng = libpng.override { apngSupport = true; };
  libpng12 = callPackage ../development/libraries/libpng/12.nix { };
  libpng15 = callPackage ../development/libraries/libpng/15.nix { };

  libpaper = callPackage ../development/libraries/libpaper { };

  libproxy = callPackage ../development/libraries/libproxy {
    stdenv = if stdenv.isDarwin
      then overrideGCC stdenv gcc
      else stdenv;
  };

  libpseudo = callPackage ../development/libraries/libpseudo { };

  libpwquality = callPackage ../development/libraries/libpwquality { };

  libqalculate = callPackage ../development/libraries/libqalculate { };

  librsvg = callPackage ../development/libraries/librsvg {
    gtk2 = null; gtk3 = null; # neither gtk version by default
  };

  librsync = callPackage ../development/libraries/librsync { };

  libsearpc = callPackage ../development/libraries/libsearpc { };

  libsigcxx = callPackage ../development/libraries/libsigcxx { };

  libsigcxx12 = callPackage ../development/libraries/libsigcxx/1.2.nix { };

  libsigsegv = callPackage ../development/libraries/libsigsegv { };

  # To bootstrap SBCL, I need CLisp 2.44.1; it needs libsigsegv 2.5
  libsigsegv_25 = callPackage ../development/libraries/libsigsegv/2.5.nix { };

  libsndfile = callPackage ../development/libraries/libsndfile { };

  libsodium = callPackage ../development/libraries/libsodium { };

  libsoup = callPackage ../development/libraries/libsoup { };

  libssh = callPackage ../development/libraries/libssh { };

  libssh2 = callPackage ../development/libraries/libssh2 { };

  libstartup_notification = callPackage ../development/libraries/startup-notification { };

  libspatialindex = callPackage ../development/libraries/libspatialindex { };

  libspatialite = callPackage ../development/libraries/libspatialite { };

  libstatgrab = callPackage ../development/libraries/libstatgrab { };

  libtar = callPackage ../development/libraries/libtar { };

  libtasn1 = callPackage ../development/libraries/libtasn1 { };

  libtheora = callPackage ../development/libraries/libtheora { };

  libtiff = callPackage ../development/libraries/libtiff { };

  libtiger = callPackage ../development/libraries/libtiger { };

  libtommath = callPackage ../development/libraries/libtommath { };

  libtomcrypt = callPackage ../development/libraries/libtomcrypt { };

  libtorrentRasterbar = callPackage ../development/libraries/libtorrent-rasterbar {
    # fix "unrecognized option -arch" error
    stdenv = if stdenv.isDarwin
      then clangStdenv
      else stdenv;
  };

  libtorrentRasterbar_0_16 = callPackage ../development/libraries/libtorrent-rasterbar/0.16.nix {
    # fix "unrecognized option -arch" error
    stdenv = if stdenv.isDarwin
      then clangStdenv
      else stdenv;
  };

  libtoxcore = callPackage ../development/libraries/libtoxcore { };

  libtsm = callPackage ../development/libraries/libtsm { };

  libtunepimp = callPackage ../development/libraries/libtunepimp { };

  libtxc_dxtn = callPackage ../development/libraries/libtxc_dxtn { };

  libtxc_dxtn_s2tc = callPackage ../development/libraries/libtxc_dxtn_s2tc { };

  libgeotiff = callPackage ../development/libraries/libgeotiff { };

  libu2f-host = callPackage ../development/libraries/libu2f-host { };

  libunistring = callPackage ../development/libraries/libunistring { };

  libupnp = callPackage ../development/libraries/pupnp { };

  giflib = giflib_5_1;
  giflib_4_1 = callPackage ../development/libraries/giflib/4.1.nix { };
  giflib_5_0 = callPackage ../development/libraries/giflib/5.0.nix { };
  giflib_5_1 = callPackage ../development/libraries/giflib/5.1.nix { };

  libungif = callPackage ../development/libraries/giflib/libungif.nix { };

  libunibreak = callPackage ../development/libraries/libunibreak { };

  libunique = callPackage ../development/libraries/libunique/default.nix { };

  liburcu = callPackage ../development/libraries/liburcu { };

  libusb = callPackage ../development/libraries/libusb {};

  libusb1 = callPackage ../development/libraries/libusb1 {
    stdenv = if stdenv.isDarwin
      then clangStdenv
      else stdenv;
  };

  libunwind = callPackage ../development/libraries/libunwind { };

  libuvVersions = callPackage ../development/libraries/libuv { };

  libv4l = lowPrio (v4l_utils.override {
    withQt4 = false;
  });

  libva = callPackage ../development/libraries/libva { };

  libvdpau = callPackage ../development/libraries/libvdpau { };

  libvirt = callPackage ../development/libraries/libvirt { };

  libvirt-glib = callPackage ../development/libraries/libvirt-glib { };

  libvisio = callPackage ../development/libraries/libvisio { };

  libvisual = callPackage ../development/libraries/libvisual { };

  libvncserver = callPackage ../development/libraries/libvncserver {};

  libviper = callPackage ../development/libraries/libviper { };

  libvpx = callPackage ../development/libraries/libvpx { };

  libvterm = callPackage ../development/libraries/libvterm { };

  libvorbis = callPackage ../development/libraries/libvorbis { };

  libwebp = callPackage ../development/libraries/libwebp { };

  libwmf = callPackage ../development/libraries/libwmf { };

  libwnck = libwnck2;
  libwnck2 = callPackage ../development/libraries/libwnck { };
  libwnck3 = callPackage ../development/libraries/libwnck/3.x.nix { };

  libwpd = callPackage ../development/libraries/libwpd { };

  libwpd_08 = callPackage ../development/libraries/libwpd/0.8.nix { };

  libwpg = callPackage ../development/libraries/libwpg { };

  libx86 = builderDefsPackage ../development/libraries/libx86 {};

  libxdg_basedir = callPackage ../development/libraries/libxdg-basedir { };

  libxkbcommon = callPackage ../development/libraries/libxkbcommon { };

  libxklavier = callPackage ../development/libraries/libxklavier { };

  libxls = callPackage ../development/libraries/libxls { };

  libxmi = callPackage ../development/libraries/libxmi { };

  libxml2 = callPackage ../development/libraries/libxml2 {
    pythonSupport = false;
  };

  libxml2Python = lowPrio (libxml2.override {
    pythonSupport = true;
  });

  libxmlxx = callPackage ../development/libraries/libxmlxx { };

  libxmp = callPackage ../development/libraries/libxmp { };

  libxslt = callPackage ../development/libraries/libxslt { };

  libixp_for_wmii = lowPrio (import ../development/libraries/libixp_for_wmii {
    inherit fetchurl stdenv;
  });

  libyaml = callPackage ../development/libraries/libyaml { };

  libyamlcpp = callPackage ../development/libraries/libyaml-cpp { };

  libykneomgr = callPackage ../development/libraries/libykneomgr { };

  libyubikey = callPackage ../development/libraries/libyubikey { };

  libzip = callPackage ../development/libraries/libzip { };

  libzdb = callPackage ../development/libraries/libzdb { };

  libzrtpcpp = callPackage ../development/libraries/libzrtpcpp { };
  libzrtpcpp_1_6 = callPackage ../development/libraries/libzrtpcpp/1.6.nix {
    ccrtp = ccrtp_1_8;
  };

  libwacom = callPackage ../development/libraries/libwacom { };

  lightning = callPackage ../development/libraries/lightning { };

  lirc = callPackage ../development/libraries/lirc { };

  liquidfun = callPackage ../development/libraries/liquidfun { };

  liquidwar = builderDefsPackage ../games/liquidwar {
    inherit (xlibs) xproto libX11 libXrender;
    inherit gmp mesa libjpeg
      expat gettext perl
      SDL SDL_image SDL_mixer SDL_ttf
      curl sqlite
      libogg libvorbis libcaca csound cunit
      ;
    guile = guile_1_8;
    libpng = libpng15; # 0.0.13 needs libpng 1.2--1.5
  };

  log4cpp = callPackage ../development/libraries/log4cpp { };

  log4cxx = callPackage ../development/libraries/log4cxx { };

  log4cplus = callPackage ../development/libraries/log4cplus { };

  loudmouth = callPackage ../development/libraries/loudmouth { };

  lzo = callPackage ../development/libraries/lzo { };

  matio = callPackage ../development/libraries/matio { };

  mdds_0_7_1 = callPackage ../development/libraries/mdds/0.7.1.nix { };
  mdds = callPackage ../development/libraries/mdds { };

  # failed to build
  mediastreamer = callPackage ../development/libraries/mediastreamer { };

  menu-cache = callPackage ../development/libraries/menu-cache { };

  mesaSupported = lib.elem system lib.platforms.mesaPlatforms;

  mesaDarwinOr = alternative: if stdenv.isDarwin
    then callPackage ../development/libraries/mesa-darwin { }
    else alternative;
  mesa_noglu = mesaDarwinOr (callPackage ../development/libraries/mesa {
    # makes it slower, but during runtime we link against just mesa_drivers
    # through /run/opengl-driver*, which is overriden according to config.grsecurity
    grsecEnabled = true;
  });
  mesa_glu =  mesaDarwinOr (callPackage ../development/libraries/mesa-glu { });
  mesa_drivers = mesaDarwinOr (
    let mo = mesa_noglu.override {
      grsecEnabled = config.grsecurity or false;
    };
    in mo.drivers
  );
  mesa = mesaDarwinOr (buildEnv {
    name = "mesa-${mesa_noglu.version}";
    paths = [ mesa_noglu mesa_glu ];
  });

  metaEnvironment = recurseIntoAttrs (let callPackage = newScope pkgs.metaEnvironment; in rec {
    sdfLibrary    = callPackage ../development/libraries/sdf-library { aterm = aterm28; };
    toolbuslib    = callPackage ../development/libraries/toolbuslib { aterm = aterm28; inherit (windows) w32api; };
    cLibrary      = callPackage ../development/libraries/c-library { aterm = aterm28; };
    errorSupport  = callPackage ../development/libraries/error-support { aterm = aterm28; };
    ptSupport     = callPackage ../development/libraries/pt-support { aterm = aterm28; };
    ptableSupport = callPackage ../development/libraries/ptable-support { aterm = aterm28; };
    configSupport = callPackage ../development/libraries/config-support { aterm = aterm28; };
    asfSupport    = callPackage ../development/libraries/asf-support { aterm = aterm28; };
    tideSupport   = callPackage ../development/libraries/tide-support { aterm = aterm28; };
    rstoreSupport = callPackage ../development/libraries/rstore-support { aterm = aterm28; };
    sdfSupport    = callPackage ../development/libraries/sdf-support { aterm = aterm28; };
    sglr          = callPackage ../development/libraries/sglr { aterm = aterm28; };
    ascSupport    = callPackage ../development/libraries/asc-support { aterm = aterm28; };
    pgen          = callPackage ../development/libraries/pgen { aterm = aterm28; };
  });

  ming = callPackage ../development/libraries/ming { };

  minizip = callPackage ../development/libraries/minizip { };

  minmay = callPackage ../development/libraries/minmay { };

  miro = callPackage ../applications/video/miro {
    inherit (pythonPackages) pywebkitgtk pysqlite pycurl mutagen;
    avahi = avahi.override {
      withLibdnssdCompat = true;
    };
  };

  mkvtoolnix = callPackage ../applications/video/mkvtoolnix { };

  mlt-qt4 = callPackage ../development/libraries/mlt {
    qt = qt4;
  };

  mlt-qt5 = callPackage ../development/libraries/mlt {
    qt = qt5;
  };

  movit = callPackage ../development/libraries/movit { };

  mps = callPackage ../development/libraries/mps { };

  libmpeg2 = callPackage ../development/libraries/libmpeg2 { };

  mpeg2dec = libmpeg2;

  msilbc = callPackage ../development/libraries/msilbc { };

  mp4v2 = callPackage ../development/libraries/mp4v2 { };

  mpc = callPackage ../development/libraries/mpc { };

  mpich2 = callPackage ../development/libraries/mpich2 { };

  mtdev = callPackage ../development/libraries/mtdev { };

  mtpfs = callPackage ../tools/filesystems/mtpfs { };

  mu = callPackage ../tools/networking/mu {
    texinfo = texinfo4;
  };

  muparser = callPackage ../development/libraries/muparser { };

  mygpoclient = callPackage ../development/python-modules/mygpoclient { };

  mygui = callPackage ../development/libraries/mygui {};

  myguiSvn = callPackage ../development/libraries/mygui/svn.nix {};

  mysocketw = callPackage ../development/libraries/mysocketw { };

  mythes = callPackage ../development/libraries/mythes { };

  nanomsg = callPackage ../development/libraries/nanomsg { };

  ncurses = callPackage ../development/libraries/ncurses {
    unicode = system != "i686-cygwin";
  };

  neon = callPackage ../development/libraries/neon {
    compressionSupport = true;
    sslSupport = true;
  };

  nethack = builderDefsPackage (import ../games/nethack) {
    inherit ncurses flex bison;
  };

  nettle = callPackage ../development/libraries/nettle { };

  newt = callPackage ../development/libraries/newt { };

  nix-plugins = callPackage ../development/libraries/nix-plugins {
    nix = pkgs.nixUnstable;
  };

  nspr = callPackage ../development/libraries/nspr { };

  nss = lowPrio (callPackage ../development/libraries/nss { });

  nssTools = callPackage ../development/libraries/nss {
    includeTools = true;
  };

  ntrack = callPackage ../development/libraries/ntrack { };

  nvidia-texture-tools = callPackage ../development/libraries/nvidia-texture-tools { };

  ode = builderDefsPackage (import ../development/libraries/ode) { };

  ogre = callPackage ../development/libraries/ogre {};

  ogrepaged = callPackage ../development/libraries/ogrepaged { };

  oniguruma = callPackage ../development/libraries/oniguruma { };

  openal = callPackage ../development/libraries/openal { };

  # added because I hope that it has been easier to compile on x86 (for blender)
  openalSoft = callPackage ../development/libraries/openal-soft { };

  openbabel = callPackage ../development/libraries/openbabel { };

  opencascade = callPackage ../development/libraries/opencascade { };

  opencascade_6_5 = callPackage ../development/libraries/opencascade/6.5.nix {
    automake = automake111x;
    ftgl = ftgl212;
  };

  opencascade_oce = callPackage ../development/libraries/opencascade/oce.nix { };

  opencsg = callPackage ../development/libraries/opencsg { };

  openct = callPackage ../development/libraries/openct { };

  opencv = callPackage ../development/libraries/opencv { };

  opencv_2_1 = callPackage ../development/libraries/opencv/2.1.nix {
    libpng = libpng12;
  };

  # this ctl version is needed by openexr_viewers
  openexr_ctl = callPackage ../development/libraries/openexr_ctl { };

  openexr = dropCxx (callPackage ../development/libraries/openexr { });

  openldap = callPackage ../development/libraries/openldap {
    stdenv = if stdenv.isDarwin
      then clangStdenv
      else stdenv;
  };

  openlierox = callPackage ../games/openlierox { };

  libopensc_dnie = callPackage ../development/libraries/libopensc-dnie { };

  opencolorio = callPackage ../development/libraries/opencolorio { };

  ois = callPackage ../development/libraries/ois {};

  opal = callPackage ../development/libraries/opal {};

  openjpeg = callPackage ../development/libraries/openjpeg { lcms = lcms2; };

  openscenegraph = callPackage ../development/libraries/openscenegraph {
    giflib = giflib_4_1;
    ffmpeg = ffmpeg_0_10;
  };

  openspades = callPackage ../games/openspades {};

  libressl = callPackage ../development/libraries/libressl { };

  boringssl = callPackage ../development/libraries/boringssl { };

  openssl = callPackage ../development/libraries/openssl {
    fetchurl = fetchurlBoot;
    cryptodevHeaders = linuxPackages.cryptodev.override {
      fetchurl = fetchurlBoot;
      onlyHeaders = true;
    };
  };

  ortp = callPackage ../development/libraries/ortp {
    srtp = srtp_linphone;
  };

  p11_kit = callPackage ../development/libraries/p11-kit { };

  paperkey = callPackage ../tools/security/paperkey { };

  pangoxsl = callPackage ../development/libraries/pangoxsl { };

  pcl = callPackage ../development/libraries/pcl {
    vtk = vtkWithQt4;
  };

  pcre = callPackage ../development/libraries/pcre {
    unicodeSupport = config.pcre.unicode or true;
  };

  pdf2xml = callPackage ../development/libraries/pdf2xml {} ;

  phonon = callPackage ../development/libraries/phonon { };

  phonon_backend_gstreamer = callPackage ../development/libraries/phonon-backend-gstreamer { };

  phonon_backend_vlc = callPackage ../development/libraries/phonon-backend-vlc { };

  physfs = callPackage ../development/libraries/physfs { };

  pipelight = callPackage ../tools/misc/pipelight { };

  pkcs11helper = callPackage ../development/libraries/pkcs11helper { };

  plib = callPackage ../development/libraries/plib { };

  pocketsphinx = callPackage ../development/libraries/pocketsphinx { };

  podofo = callPackage ../development/libraries/podofo { lua5 = lua5_1; };

  polkit = callPackage ../development/libraries/polkit {
    spidermonkey = spidermonkey_185;
  };

  polkit_qt_1 = callPackage ../development/libraries/polkit-qt-1 { };

  policykit = callPackage ../development/libraries/policykit { };

  poppler = callPackage ../development/libraries/poppler { lcms = lcms2; };
  popplerQt4 = poppler.poppler_qt4;

  popt = callPackage ../development/libraries/popt { };

  portaudio = callPackage ../development/libraries/portaudio {
    # resolves a variety of compile-time errors
    stdenv = if stdenv.isDarwin
      then clangStdenv
      else stdenv;
  };

  portaudioSVN = callPackage ../development/libraries/portaudio/svn-head.nix { };

  portmidi = callPackage ../development/libraries/portmidi {};

  prison = callPackage ../development/libraries/prison { };

  proj = callPackage ../development/libraries/proj { };

  postgis = callPackage ../development/libraries/postgis { };

  protobuf = callPackage ../development/libraries/protobuf { };

  protobufc = callPackage ../development/libraries/protobufc { };

  pth = callPackage ../development/libraries/pth { };

  ptlib = callPackage ../development/libraries/ptlib {};

  re2 = callPackage ../development/libraries/re2 { };

  qca2 = callPackage ../development/libraries/qca2 {};

  qca2_ossl = callPackage ../development/libraries/qca2/ossl.nix {};

  qimageblitz = callPackage ../development/libraries/qimageblitz {};

  qjson = callPackage ../development/libraries/qjson { };

  qoauth = callPackage ../development/libraries/qoauth { };

  quazip = callPackage ../development/libraries/quazip {
    qt = qt5;
  };

  qt3 = callPackage ../development/libraries/qt-3 {
    openglSupport = mesaSupported;
    libpng = libpng12;
  };

  qt4 = pkgs.kde4.qt4;

  qt48 = callPackage ../development/libraries/qt-4.x/4.8 {
    # GNOME dependencies are not used unless gtkStyle == true
    mesa = mesa_noglu;
    inherit (pkgs.gnome) libgnomeui GConf gnome_vfs;
    cups = if stdenv.isLinux then cups else null;

    # resolve unrecognised flag '-fconstant-cfstrings' errors
    stdenv = if stdenv.isDarwin
      then clangStdenv
      else stdenv;
  };

  qt48Full = appendToName "full" (qt48.override {
    docs = true;
    demos = true;
    examples = true;
    developerBuild = true;
  });

  qt4SDK = qtcreator.override {
    sdkBuild = true;
    qtLib = qt48Full;
  };

  qt53Full = appendToName "full" (qt53.override {
    buildDocs = true;
    buildExamples = true;
    buildTests = true;
    developerBuild = true;
  });

  qt53 = callPackage ../development/libraries/qt-5/qt-5.3.nix {
    mesa = mesa_noglu;
    cups = if stdenv.isLinux then cups else null;
    # GNOME dependencies are not used unless gtkStyle == true
    inherit (gnome) libgnomeui GConf gnome_vfs;
    bison = bison2; # error: too few arguments to function 'int yylex(...
  };

  qt5 = callPackage ../development/libraries/qt-5 {
    mesa = mesa_noglu;
    cups = if stdenv.isLinux then cups else null;
    # GNOME dependencies are not used unless gtkStyle == true
    inherit (gnome) libgnomeui GConf gnome_vfs;
    bison = bison2; # error: too few arguments to function 'int yylex(...
  };

  qt5Full = appendToName "full" (qt5.override {
    buildDocs = true;
    buildExamples = true;
    buildTests = true;
    developerBuild = true;
  });

  qt5SDK = qtcreator.override {
    sdkBuild = true;
    qtLib = qt5Full;
  };

  qtcreator = callPackage ../development/qtcreator {
    qtLib = qt48.override { developerBuild = true; };
  };

  qtkeychain = callPackage ../development/libraries/qtkeychain { };

  qtscriptgenerator = callPackage ../development/libraries/qtscriptgenerator { };

  quesoglc = callPackage ../development/libraries/quesoglc { };

  qwt = callPackage ../development/libraries/qwt {};

  qwt6 = callPackage ../development/libraries/qwt/6.nix { };

  rabbitmq-c = callPackage ../development/libraries/rabbitmq-c {};

  rabbitmq-java-client = callPackage ../development/libraries/rabbitmq-java-client {};

  raul = callPackage ../development/libraries/audio/raul { };

  readline = readline6;
  readline6 = readline63;

  readline5 = callPackage ../development/libraries/readline/5.x.nix { };

  readline62 = callPackage ../development/libraries/readline/6.2.nix { };

  readline63 = callPackage ../development/libraries/readline/6.3.nix { };

  librdf_raptor = callPackage ../development/libraries/librdf/raptor.nix { };

  librdf_raptor2 = callPackage ../development/libraries/librdf/raptor2.nix { };

  librdf_rasqal = callPackage ../development/libraries/librdf/rasqal.nix { };

  librdf_redland = callPackage ../development/libraries/librdf/redland.nix { };

  librdf = callPackage ../development/libraries/librdf { };

  lilv = callPackage ../development/libraries/audio/lilv { };

  lv2 = callPackage ../development/libraries/audio/lv2 { };

  lvtk = callPackage ../development/libraries/audio/lvtk { };

  qrupdate = callPackage ../development/libraries/qrupdate { };

  redland = pkgs.librdf_redland;

  rhino = callPackage ../development/libraries/java/rhino {
    javac = gcj;
    jvm = gcj;
  };

  rlog = callPackage ../development/libraries/rlog { };

  rubberband = callPackage ../development/libraries/rubberband {
    fftw = fftwSinglePrec;
    inherit (vamp) vampSDK;
  };

  sbc = callPackage ../development/libraries/sbc { };

  schroedinger = callPackage ../development/libraries/schroedinger { };

  SDL = callPackage ../development/libraries/SDL {
    openglSupport = mesaSupported;
    alsaSupport = (!stdenv.isDarwin);
    x11Support = true;
    pulseaudioSupport = true;

    # resolve the unrecognized -fpascal-strings option error
    stdenv = if stdenv.isDarwin
      then clangStdenv
      else stdenv;
  };

  SDL_gfx = callPackage ../development/libraries/SDL_gfx { };

  SDL_image = callPackage ../development/libraries/SDL_image {
    # provide an Objective-C compiler
    stdenv = if stdenv.isDarwin
      then clangStdenv
      else stdenv;
  };

  SDL_mixer = callPackage ../development/libraries/SDL_mixer { };

  SDL_net = callPackage ../development/libraries/SDL_net { };

  SDL_sound = callPackage ../development/libraries/SDL_sound { };

  SDL_ttf = callPackage ../development/libraries/SDL_ttf { };

  SDL2 = callPackage ../development/libraries/SDL2 {
    openglSupport = mesaSupported;
    alsaSupport = true;
    x11Support = true;
    pulseaudioSupport = false; # better go through ALSA
  };

  SDL2_image = callPackage ../development/libraries/SDL2_image { };

  SDL2_mixer = callPackage ../development/libraries/SDL2_mixer { };

  SDL2_net = callPackage ../development/libraries/SDL2_net { };

  SDL2_gfx = callPackage ../development/libraries/SDL2_gfx { };

  serd = callPackage ../development/libraries/serd {};

  serf = callPackage ../development/libraries/serf {};

  silgraphite = callPackage ../development/libraries/silgraphite {};
  graphite2 = callPackage ../development/libraries/silgraphite/graphite2.nix {};

  simgear = callPackage ../development/libraries/simgear { };

  sfml_git = callPackage ../development/libraries/sfml { };

  skalibs = callPackage ../development/libraries/skalibs { };

  slang = callPackage ../development/libraries/slang { };

  slibGuile = callPackage ../development/libraries/slib {
    scheme = guile_1_8;
    texinfo = texinfo4; # otherwise erros: must be after `@defun' to use `@defunx'
  };

  smpeg = callPackage ../development/libraries/smpeg { };

  snack = callPackage ../development/libraries/snack {
        # optional
  };

  snappy = callPackage ../development/libraries/snappy { };

  sodium = callPackage ../development/libraries/sodium {};

  sofia_sip = callPackage ../development/libraries/sofia-sip { };

  soprano = callPackage ../development/libraries/soprano { };

  soqt = callPackage ../development/libraries/soqt { };

  sord = callPackage ../development/libraries/sord {};

  spandsp = callPackage ../development/libraries/spandsp {};

  speechd = callPackage ../development/libraries/speechd { };

  speech_tools = callPackage ../development/libraries/speech-tools {};

  speex = callPackage ../development/libraries/speex { };

  sphinxbase = callPackage ../development/libraries/sphinxbase { };

  sphinxsearch = callPackage ../servers/search/sphinxsearch { };

  spice = callPackage ../development/libraries/spice {
    celt = celt_0_5_1;
    inherit (xlibs) libXrandr libXfixes libXext libXrender libXinerama;
    inherit (pythonPackages) pyparsing;
  };

  spice_gtk = callPackage ../development/libraries/spice-gtk { };

  spice_protocol = callPackage ../development/libraries/spice-protocol { };

  sratom = callPackage ../development/libraries/audio/sratom { };

  srtp = callPackage ../development/libraries/srtp {};

  srtp_linphone = callPackage ../development/libraries/srtp/linphone.nix { };

  sqlite = lowPrio (callPackage ../development/libraries/sqlite { });

  sqliteInteractive = appendToName "interactive" (sqlite.override { interactive = true; });

  sqlcipher = lowPrio (callPackage ../development/libraries/sqlcipher {
    readline = null;
    ncurses = null;
  });

  stfl = callPackage ../development/libraries/stfl {
    stdenv = if stdenv.isDarwin
      then overrideGCC stdenv gccApple
      else stdenv;
  };

  stlink = callPackage ../development/tools/misc/stlink { };

  steghide = callPackage ../tools/security/steghide {};

  stepmania = callPackage ../games/stepmania {};

  stlport = callPackage ../development/libraries/stlport { };

  strigi = callPackage ../development/libraries/strigi { clucene_core = clucene_core_2; };

  subtitleeditor = callPackage ../applications/video/subtitleeditor { };

  suil = callPackage ../development/libraries/audio/suil { };

  suitesparse = callPackage ../development/libraries/suitesparse { };

  sutils = callPackage ../tools/misc/sutils { };

  sword = callPackage ../development/libraries/sword { };

  szip = callPackage ../development/libraries/szip { };

  t1lib = callPackage ../development/libraries/t1lib { };

  taglib = callPackage ../development/libraries/taglib { };

  taglib_extras = callPackage ../development/libraries/taglib-extras { };

  talloc = callPackage ../development/libraries/talloc {
    libgcrypt = libgcrypt_1_6;
  };

  tclap = callPackage ../development/libraries/tclap {};

  tclgpg = callPackage ../development/libraries/tclgpg { };

  tcllib = callPackage ../development/libraries/tcllib { };

  tcltls = callPackage ../development/libraries/tcltls { };

  tdb = callPackage ../development/libraries/tdb {
    sasl = cyrus_sasl;
    libgcrypt = libgcrypt_1_6;
  };

  tecla = callPackage ../development/libraries/tecla { };

  telepathy_glib = callPackage ../development/libraries/telepathy/glib { };

  telepathy_farstream = callPackage ../development/libraries/telepathy/farstream {};

  telepathy_qt = callPackage ../development/libraries/telepathy/qt { };

  tevent = callPackage ../development/libraries/tevent {
    libgcrypt = libgcrypt_1_6;
    sasl = cyrus_sasl;
  };

  thrift = callPackage ../development/libraries/thrift { };

  tinyxml = tinyxml2;

  tinyxml2 = callPackage ../development/libraries/tinyxml/2.6.2.nix { };

  tk = callPackage ../development/libraries/tk { };

  tnt = callPackage ../development/libraries/tnt { };

  kyotocabinet = callPackage ../development/libraries/kyotocabinet { };

  tokyocabinet = callPackage ../development/libraries/tokyo-cabinet { };

  tokyotyrant = callPackage ../development/libraries/tokyo-tyrant { };

  tremor = callPackage ../development/libraries/tremor { };

  unicap = callPackage ../development/libraries/unicap {};

  tsocks = callPackage ../development/libraries/tsocks { };

  unixODBC = callPackage ../development/libraries/unixODBC { };

  unixODBCDrivers = recurseIntoAttrs (import ../development/libraries/unixODBCDrivers {
    inherit fetchurl stdenv unixODBC glibc libtool openssl zlib;
    inherit postgresql mysql sqlite;
  });

  urt = callPackage ../development/libraries/urt { };

  ustr = callPackage ../development/libraries/ustr { };

  usbredir = callPackage ../development/libraries/usbredir {
    libusb = libusb1;
  };

  ucommon = callPackage ../development/libraries/ucommon { };

  v8 = callPackage ../development/libraries/v8 {
    inherit (pythonPackages) gyp;
  };

  vaapiIntel = callPackage ../development/libraries/vaapi-intel { };

  vaapiVdpau = callPackage ../development/libraries/vaapi-vdpau { };

  vamp = callPackage ../development/libraries/audio/vamp { };

  vcdimager = callPackage ../development/libraries/vcdimager { };

  vigra = callPackage ../development/libraries/vigra {
    inherit (pkgs.pythonPackages) numpy;
  };

  vlock = callPackage ../misc/screensavers/vlock { };

  vmime = callPackage ../development/libraries/vmime { };

  vrpn = callPackage ../development/libraries/vrpn { };

  vtk = callPackage ../development/libraries/vtk { };

  vtkWithQt4 = vtk.override { qtLib = qt4; };

  vxl = callPackage ../development/libraries/vxl {
    libpng = libpng12;
  };

  wayland = callPackage ../development/libraries/wayland { };

  webkit = webkitgtk;

  webkitgtk = callPackage ../development/libraries/webkitgtk {
    harfbuzz = harfbuzz-icu;
    inherit (xorg) libpthreadstubs;
    gst-plugins-base = gst_all_1.gst-plugins-base;
  };

  webkitgtk24x = callPackage ../development/libraries/webkitgtk/2.4.6.nix {
    harfbuzz = harfbuzz-icu;
    gst-plugins-base = gst_all_1.gst-plugins-base;
  };

  webkitgtk2 = webkitgtk24x.override {
    withGtk2 = true;
    enableIntrospection = false;
  };

  websocketpp = callPackage ../development/libraries/websocket++ { };

  wildmidi = callPackage ../development/libraries/wildmidi { };

  wvstreams = callPackage ../development/libraries/wvstreams { };

  wxGTK = wxGTK28;

  wxGTK28 = callPackage ../development/libraries/wxGTK-2.8 {
    inherit (gnome) GConf;
    withMesa = lib.elem system lib.platforms.mesaPlatforms;
  };

  wxGTK29 = callPackage ../development/libraries/wxGTK-2.9/default.nix {
    inherit (gnome) GConf;
    withMesa = lib.elem system lib.platforms.mesaPlatforms;

    # use for Objective-C++ compiler
    stdenv = if stdenv.isDarwin
      then clangStdenv
      else stdenv;
  };

  wxGTK30 = callPackage ../development/libraries/wxGTK-3.0/default.nix {
    inherit (gnome) GConf;
    withMesa = lib.elem system lib.platforms.mesaPlatforms;

    # use for Objective-C++ compiler
    stdenv = if stdenv.isDarwin
      then clangStdenv
      else stdenv;
  };

  wtk = callPackage ../development/libraries/wtk { };

  x264 = callPackage ../development/libraries/x264 { };

  x265 = callPackage ../development/libraries/x265 { };

  x265-hg = callPackage ../development/libraries/x265/hg.nix { };

  xapian = callPackage ../development/libraries/xapian { };

  xapianBindings = callPackage ../development/libraries/xapian/bindings {  # TODO perl php Java, tcl, C#, python
  };

  xapian10 = callPackage ../development/libraries/xapian/1.0.x.nix { };

  xapianBindings10 = callPackage ../development/libraries/xapian/bindings/1.0.x.nix {  # TODO perl php Java, tcl, C#, python
  };

  Xaw3d = callPackage ../development/libraries/Xaw3d { };

  xbase = callPackage ../development/libraries/xbase { };

  xcb-util-cursor = callPackage ../development/libraries/xcb-util-cursor { };

  xdo = callPackage ../tools/misc/xdo { };

  xineLib = callPackage ../development/libraries/xine-lib {
    ffmpeg = ffmpeg_1;
  };

  xautolock = callPackage ../misc/screensavers/xautolock { };

  xercesc = callPackage ../development/libraries/xercesc {};

  xlibsWrapper = callPackage ../development/libraries/xlibs-wrapper {
    packages = [
      freetype fontconfig xlibs.xproto xlibs.libX11 xlibs.libXt
      xlibs.libXft xlibs.libXext xlibs.libSM xlibs.libICE
      xlibs.xextproto
    ];
  };

  xmlrpc_c = callPackage ../development/libraries/xmlrpc-c { };

  xmlsec = callPackage ../development/libraries/xmlsec { };

  xlslib = callPackage ../development/libraries/xlslib { };

  xvidcore = callPackage ../development/libraries/xvidcore { };

  xylib = callPackage ../development/libraries/xylib { };

  yajl = callPackage ../development/libraries/yajl { };

  yubico-piv-tool = callPackage ../tools/misc/yubico-piv-tool { };

  yubikey-personalization = callPackage ../tools/misc/yubikey-personalization {
    libusb = libusb1;
  };

  yubikey-personalization-gui = callPackage ../tools/misc/yubikey-personalization-gui {
    qt = qt4;
  };

  zangband = builderDefsPackage (import ../games/zangband) {
    inherit ncurses flex bison autoconf automake m4 coreutils;
  };

  zeitgeist = callPackage ../development/libraries/zeitgeist { };

  zlib = callPackage ../development/libraries/zlib {
    fetchurl = fetchurlBoot;
  };

  zlibStatic = lowPrio (appendToName "static" (callPackage ../development/libraries/zlib {
    static = true;
  }));

  zeromq2 = callPackage ../development/libraries/zeromq/2.x.nix {};
  zeromq3 = callPackage ../development/libraries/zeromq/3.x.nix {};
  zeromq4 = callPackage ../development/libraries/zeromq/4.x.nix {};

  cppzmq = callPackage ../development/libraries/cppzmq {};

  zziplib = callPackage ../development/libraries/zziplib { };

  ### DEVELOPMENT / LIBRARIES / AGDA

  agda = callPackage ../build-support/agda {
    glibcLocales = if pkgs.stdenv.isLinux then pkgs.glibcLocales else null;
    extension = self : super : {};
    Agda = haskellPackages.Agda;
    inherit writeScriptBin;
  };

  agdaBase = callPackage ../development/libraries/agda/agda-base {};

  agdaIowaStdlib = callPackage ../development/libraries/agda/agda-iowa-stdlib {};

  agdaPrelude = callPackage ../development/libraries/agda/agda-prelude {};

  AgdaStdlib = callPackage ../development/compilers/agda/stdlib.nix {
    inherit (haskellPackages) ghc filemanip;
  };

  AgdaSheaves = callPackage ../development/libraries/agda/AgdaSheaves {};

  bitvector = callPackage ../development/libraries/agda/bitvector {};

  categories = callPackage ../development/libraries/agda/categories {};

  pretty = callPackage ../development/libraries/agda/pretty {};

  TotalParserCombinators = callPackage ../development/libraries/agda/TotalParserCombinators {};

  ### DEVELOPMENT / LIBRARIES / JAVA

  atermjava = callPackage ../development/libraries/java/aterm {
    stdenv = overrideInStdenv stdenv [gnumake380];
  };

  commonsBcel = callPackage ../development/libraries/java/commons/bcel { };

  commonsBsf = callPackage ../development/libraries/java/commons/bsf { };

  commonsCompress = callPackage ../development/libraries/java/commons/compress { };

  commonsFileUpload = callPackage ../development/libraries/java/commons/fileupload { };

  commonsLang = callPackage ../development/libraries/java/commons/lang { };

  commonsLogging = callPackage ../development/libraries/java/commons/logging { };

  commonsIo = callPackage ../development/libraries/java/commons/io { };

  commonsMath = callPackage ../development/libraries/java/commons/math { };

  fastjar = callPackage ../development/tools/java/fastjar { };

  httpunit = callPackage ../development/libraries/java/httpunit { };

  gwtdragdrop = callPackage ../development/libraries/java/gwt-dragdrop { };

  gwtwidgets = callPackage ../development/libraries/java/gwt-widgets { };

  javaCup = callPackage ../development/libraries/java/cup { };

  javasvn = callPackage ../development/libraries/java/javasvn { };

  jclasslib = callPackage ../development/tools/java/jclasslib { };

  jdom = callPackage ../development/libraries/java/jdom { };

  jflex = callPackage ../development/libraries/java/jflex { };

  jjtraveler = callPackage ../development/libraries/java/jjtraveler {
    stdenv = overrideInStdenv stdenv [gnumake380];
  };

  junit = callPackage ../development/libraries/java/junit { antBuild = releaseTools.antBuild; };

  junixsocket = callPackage ../development/libraries/java/junixsocket { };

  jzmq = callPackage ../development/libraries/java/jzmq { };

  lucene = callPackage ../development/libraries/java/lucene { };

  lucenepp = callPackage ../development/libraries/lucene++ { };

  mockobjects = callPackage ../development/libraries/java/mockobjects { };

  saxon = callPackage ../development/libraries/java/saxon { };

  saxonb = callPackage ../development/libraries/java/saxon/default8.nix { };

  sharedobjects = callPackage ../development/libraries/java/shared-objects {
    stdenv = overrideInStdenv stdenv [gnumake380];
  };

  smack = callPackage ../development/libraries/java/smack { };

  swt = callPackage ../development/libraries/java/swt {
    inherit (gnome) libsoup;
  };


  ### DEVELOPMENT / LIBRARIES / JAVASCRIPT

  jquery = callPackage ../development/libraries/javascript/jquery { };

  jquery-ui = callPackage ../development/libraries/javascript/jquery-ui { };

  yuicompressor = callPackage ../development/tools/yuicompressor { };

  ### DEVELOPMENT / LISP MODULES

  asdf = callPackage ../development/lisp-modules/asdf {
    texLive = null;
  };

  clwrapperFunction = callPackage ../development/lisp-modules/clwrapper;

  wrapLisp = lisp: clwrapperFunction { inherit lisp; };

  lispPackagesFor = clwrapper: callPackage ../development/lisp-modules/lisp-packages.nix {
    inherit clwrapper;
  };

  lispPackagesClisp = lispPackagesFor (wrapLisp clisp);
  lispPackagesSBCL = lispPackagesFor (wrapLisp sbcl);
  lispPackages = recurseIntoAttrs lispPackagesSBCL;


  ### DEVELOPMENT / PERL MODULES

  buildPerlPackage = import ../development/perl-modules/generic perl;

  perlPackages = recurseIntoAttrs (import ./perl-packages.nix {
    inherit pkgs;
    overrides = (config.perlPackageOverrides or (p: {})) pkgs;
  });

  perl514Packages = import ./perl-packages.nix {
    pkgs = pkgs // {
      perl = perl514;
      buildPerlPackage = import ../development/perl-modules/generic perl514;
    };
    overrides = (config.perl514PackageOverrides or (p: {})) pkgs;
  };

  perlXMLParser = perlPackages.XMLParser;

  ack = perlPackages.ack;

  perlArchiveCpio = perlPackages.ArchiveCpio;

  perlcritic = perlPackages.PerlCritic;

  planetary_annihilation = callPackage ../games/planetaryannihilation { };

  ### DEVELOPMENT / PYTHON MODULES

  # python function with default python interpreter
  buildPythonPackage = pythonPackages.buildPythonPackage;

  # `nix-env -i python-nose` installs for 2.7, the default python.
  # Therefore we do not recurse into attributes here, in contrast to
  # python27Packages. `nix-env -iA python26Packages.nose` works
  # regardless.
  python26Packages = callPackage ./python-packages.nix {
    python = python26;
    self = python26Packages;
  };

  python27Packages = lib.hiPrioSet (recurseIntoAttrs (callPackage ./python-packages.nix {
    python = python27;
    self = python27Packages;
  }));

  python32Packages = callPackage ./python-packages.nix {
    python = python32;
    self = python32Packages;
  };

  python33Packages = recurseIntoAttrs (callPackage ./python-packages.nix {
    python = python33;
    self = python33Packages;
  });

  python34Packages = recurseIntoAttrs (callPackage ./python-packages.nix {
    python = python34;
    self = python34Packages;
  });

  pypyPackages = recurseIntoAttrs (callPackage ./python-packages.nix {
    python = pypy;
    self = pypyPackages;
  });

  foursuite = callPackage ../development/python-modules/4suite { };

  bsddb3 = callPackage ../development/python-modules/bsddb3 { };

  ecdsa = callPackage ../development/python-modules/ecdsa { };

  numeric = callPackage ../development/python-modules/numeric { };

  pil = pythonPackages.pil;

  psyco = callPackage ../development/python-modules/psyco { };

  pycairo = pythonPackages.pycairo;

  pycapnp = pythonPackages.pycapnp;

  pycrypto = pythonPackages.pycrypto;

  pycups = callPackage ../development/python-modules/pycups { };

  pyexiv2 = callPackage ../development/python-modules/pyexiv2 { };

  pygame = callPackage ../development/python-modules/pygame { };

  pygobject = pythonPackages.pygobject;

  pygobject3 = pythonPackages.pygobject3;

  pygtk = pythonPackages.pygtk;

  pyGtkGlade = pythonPackages.pyGtkGlade;

  pylint = callPackage ../development/python-modules/pylint { };

  pyopenssl = pythonPackages.pyopenssl;

  rhpl = callPackage ../development/python-modules/rhpl { };

  sip = pythonPackages.sip;

  pyqt4 = callPackage ../development/python-modules/pyqt/4.x.nix {
    stdenv = if stdenv.isDarwin
      then clangStdenv
      else stdenv;
  };

  pysideApiextractor = callPackage ../development/python-modules/pyside/apiextractor.nix { };

  pysideGeneratorrunner = callPackage ../development/python-modules/pyside/generatorrunner.nix { };

  pyside = callPackage ../development/python-modules/pyside { };

  pysideTools = callPackage ../development/python-modules/pyside/tools.nix { };

  pysideShiboken = callPackage ../development/python-modules/pyside/shiboken.nix { };

  pyx = callPackage ../development/python-modules/pyx { };

  pyxml = callPackage ../development/python-modules/pyxml { };

  rbtools = callPackage ../development/python-modules/rbtools { };

  setuptools = pythonPackages.setuptools;

  slowaes = callPackage ../development/python-modules/slowaes { };

  wxPython = pythonPackages.wxPython;
  wxPython28 = pythonPackages.wxPython28;

  twisted = pythonPackages.twisted;

  ZopeInterface = pythonPackages.zope_interface;

  ### DEVELOPMENT / R MODULES

  R = callPackage ../applications/science/math/R {
    inherit (xlibs) libX11 libXt;
    texLive = texLiveAggregationFun { paths = [ texLive texLiveExtra ]; };
    withRecommendedPackages = true;
  };

  rWrapper = callPackage ../development/r-modules/wrapper.nix {
    # Those packages are usually installed as part of the R build.
    recommendedPackages = with rPackages; [ boot class cluster codetools
      foreign KernSmooth lattice MASS Matrix mgcv nlme nnet rpart
      spatial survival ];
    # Override this attribute to register additional libraries.
    packages = [];
  };

  rPackages = import ../development/r-modules/cran-packages.nix {
    inherit pkgs;
    overrides = (config.rPackageOverrides or (p: {})) pkgs;
  };

  ### SERVERS

  rdf4store = callPackage ../servers/http/4store { };

  apacheHttpd = pkgs.apacheHttpd_2_4;

  apacheHttpd_2_2 = callPackage ../servers/http/apache-httpd/2.2.nix {
    sslSupport = true;
  };

  apacheHttpd_2_4 = lowPrio (callPackage ../servers/http/apache-httpd/2.4.nix {
    sslSupport = true;
  });

  apacheHttpdPackagesFor = apacheHttpd: self: let callPackage = newScope self; in {
    inherit apacheHttpd;

    mod_dnssd = callPackage ../servers/http/apache-modules/mod_dnssd { };

    mod_evasive = callPackage ../servers/http/apache-modules/mod_evasive { };

    mod_fastcgi = callPackage ../servers/http/apache-modules/mod_fastcgi { };

    mod_python = callPackage ../servers/http/apache-modules/mod_python { };

    mod_wsgi = callPackage ../servers/http/apache-modules/mod_wsgi { };

    php = pkgs.php.override { inherit apacheHttpd; };

    subversion = pkgs.subversion.override { httpServer = true; inherit apacheHttpd; };
  };

  apacheHttpdPackages = apacheHttpdPackagesFor pkgs.apacheHttpd pkgs.apacheHttpdPackages;
  apacheHttpdPackages_2_2 = apacheHttpdPackagesFor pkgs.apacheHttpd_2_2 pkgs.apacheHttpdPackages_2_2;
  apacheHttpdPackages_2_4 = apacheHttpdPackagesFor pkgs.apacheHttpd_2_4 pkgs.apacheHttpdPackages_2_4;

  cassandra = callPackage ../servers/nosql/cassandra { };

  apache-jena = callPackage ../servers/nosql/apache-jena/binary.nix {
    java = icedtea7_jdk;
  };

  apcupsd = callPackage ../servers/apcupsd { };

  sabnzbd = callPackage ../servers/sabnzbd { };

  bind = callPackage ../servers/dns/bind { };

  bird = callPackage ../servers/bird { };

  bosun = callPackage ../servers/monitoring/bosun {};
  scollector = callPackage ../servers/monitoring/bosun/scollector.nix {};

  couchdb = callPackage ../servers/http/couchdb {
    spidermonkey = spidermonkey_185;
    python = python27;
    sphinx = python27Packages.sphinx;
    erlang = erlangR16;
  };

  dico = callPackage ../servers/dico { };

  dict = callPackage ../servers/dict {
      libmaa = callPackage ../servers/dict/libmaa.nix {};
  };

  dictdDBs = recurseIntoAttrs (import ../servers/dict/dictd-db.nix {
    inherit builderDefs;
  });

  dictDBCollector = import ../servers/dict/dictd-db-collector.nix {
    inherit stdenv lib dict;
  };

  dictdWiktionary = callPackage ../servers/dict/dictd-wiktionary.nix {};

  dictdWordnet = callPackage ../servers/dict/dictd-wordnet.nix {};

  diod = callPackage ../servers/diod { lua = lua5_1; };

  dovecot = dovecot21;

  dovecot21 = callPackage ../servers/mail/dovecot { };

  dovecot22 = callPackage ../servers/mail/dovecot/2.2.x.nix { };

  dovecot_pigeonhole = callPackage ../servers/mail/dovecot-pigeonhole { };

  etcd = callPackage ../servers/etcd { };

  ejabberd = callPackage ../servers/xmpp/ejabberd {
    erlang = erlangR16;
  };

  prosody = recurseIntoAttrs (
    callPackage ../servers/xmpp/prosody {
      lua5 = lua5_1;
      inherit (lua51Packages) luasocket luasec luaexpat luafilesystem luabitop;
  });

  elasticmq = callPackage ../servers/elasticmq { };

  etcdctl = callPackage ../development/tools/etcdctl { };

  fcgiwrap = callPackage ../servers/fcgiwrap { };

  felix = callPackage ../servers/felix { };

  felix_remoteshell = callPackage ../servers/felix/remoteshell.nix { };

  fingerd_bsd = callPackage ../servers/fingerd/bsd-fingerd { };

  firebird = callPackage ../servers/firebird { icu = null; };
  firebirdSuper = callPackage ../servers/firebird { superServer = true; };

  fleet = callPackage ../servers/fleet { };

  freepops = callPackage ../servers/mail/freepops { };

  freeswitch = callPackage ../servers/sip/freeswitch { };

  ghostOne = callPackage ../servers/games/ghost-one { };

  ircdHybrid = callPackage ../servers/irc/ircd-hybrid { };

  jboss = callPackage ../servers/http/jboss { };

  jboss_mysql_jdbc = callPackage ../servers/http/jboss/jdbc/mysql { };

  jetty = callPackage ../servers/http/jetty { };

  jetty61 = callPackage ../servers/http/jetty/6.1 { };

  jetty92 = callPackage ../servers/http/jetty/9.2.nix { };

  joseki = callPackage ../servers/http/joseki {};

  leafnode = callPackage ../servers/news/leafnode { };

  lighttpd = callPackage ../servers/http/lighttpd { };

  mailman = callPackage ../servers/mail/mailman { };

  mediatomb = callPackage ../servers/mediatomb {
    spidermonkey = spidermonkey_185;
  };

  memcached = callPackage ../servers/memcached {};

  # Backwards compatibility.
  mod_dnssd = pkgs.apacheHttpdPackages.mod_dnssd;
  mod_evasive = pkgs.apacheHttpdPackages.mod_evasive;
  mod_fastcgi = pkgs.apacheHttpdPackages.mod_fastcgi;
  mod_python = pkgs.apacheHttpdPackages.mod_python;
  mod_wsgi = pkgs.apacheHttpdPackages.mod_wsgi;

  mpd = callPackage ../servers/mpd {
    aacSupport    = config.mpd.aacSupport or true;
    ffmpegSupport = config.mpd.ffmpegSupport or true;
  };

  mpd_clientlib = callPackage ../servers/mpd/clientlib.nix { };

  miniHttpd = callPackage ../servers/http/mini-httpd {};

  mlmmj = callPackage ../servers/mail/mlmmj { };

  myserver = callPackage ../servers/http/myserver { };

  nginx = callPackage ../servers/http/nginx {
    rtmp        = true;
    fullWebDAV  = true;
    syslog      = false; # the patch is not found
    moreheaders = true;
  };
  nginxUnstable = callPackage ../servers/http/nginx/unstable.nix {
    fullWebDAV  = true;
    syslog      = false; # the patch is not found
    moreheaders = true;
  };

  ngircd = callPackage ../servers/irc/ngircd { };

  nix-binary-cache = callPackage ../servers/http/nix-binary-cache {};

  nsd = callPackage ../servers/dns/nsd (config.nsd or {});

  nsq = callPackage ../servers/nsq { };

  openresty = callPackage ../servers/http/openresty { };

  opensmtpd = callPackage ../servers/mail/opensmtpd { };

  petidomo = callPackage ../servers/mail/petidomo { };

  popa3d = callPackage ../servers/mail/popa3d { };

  postfix = callPackage ../servers/mail/postfix { };

  postfix211 = callPackage ../servers/mail/postfix/2.11.nix { };

  pulseaudio = callPackage ../servers/pulseaudio {
    gconf = gnome.GConf;
    # The following are disabled in the default build, because if this
    # functionality is desired, they are only needed in the PulseAudio
    # server.
    bluez = null;
    avahi = null;
  };
  pulseaudioFull = pulseaudio.override {
    bluez = bluez5;
    avahi = avahi;
    jackaudioSupport = true;
    x11Support = true;
  };

  tomcat_connectors = callPackage ../servers/http/apache-modules/tomcat-connectors { };

  pies = callPackage ../servers/pies { };

  portmap = callPackage ../servers/portmap { };

  rpcbind = callPackage ../servers/rpcbind { };

  #monetdb = callPackage ../servers/sql/monetdb { };

  mariadb = callPackage ../servers/sql/mariadb {};

  mongodb = callPackage ../servers/nosql/mongodb {
    sasl = cyrus_sasl;
  };

  riak = callPackage ../servers/nosql/riak/1.3.1.nix { };

  influxdb = callPackage ../servers/nosql/influxdb { };

  mysql51 = import ../servers/sql/mysql/5.1.x.nix {
    inherit fetchurl ncurses zlib perl openssl stdenv;
    ps = procps; /* !!! Linux only */
  };

  mysql55 = callPackage ../servers/sql/mysql/5.5.x.nix { };

  mysql = mysql51;

  mysql_jdbc = callPackage ../servers/sql/mysql/jdbc { };

  nagios = callPackage ../servers/monitoring/nagios { };

  munin = callPackage ../servers/monitoring/munin { };

  nagiosPluginsOfficial = callPackage ../servers/monitoring/nagios/plugins/official-2.x.nix { };

  neo4j = callPackage ../servers/nosql/neo4j { };

  net_snmp = callPackage ../servers/monitoring/net-snmp { };

  riemann = callPackage ../servers/monitoring/riemann { };

  oidentd = callPackage ../servers/identd/oidentd { };

  openfire = callPackage ../servers/xmpp/openfire { };

  oracleXE = callPackage ../servers/sql/oracle-xe { };

  OVMF = callPackage ../applications/virtualization/OVMF { };

  pgpool92 = callPackage ../servers/sql/pgpool/default.nix {
    postgresql = postgresql92;
  };

  pgpool93 = callPackage ../servers/sql/pgpool/default.nix {
    postgresql = postgresql93;
  };

  pgpool = pgpool92;

  postgresql = postgresql92;

  postgresql84 = callPackage ../servers/sql/postgresql/8.4.x.nix { };

  postgresql90 = callPackage ../servers/sql/postgresql/9.0.x.nix { };

  postgresql91 = callPackage ../servers/sql/postgresql/9.1.x.nix { };

  postgresql92 = callPackage ../servers/sql/postgresql/9.2.x.nix { };

  postgresql93 = callPackage ../servers/sql/postgresql/9.3.x.nix { };

  postgresql94beta2 = callPackage ../servers/sql/postgresql/9.4beta2.nix { };
  postgresql94beta3 = callPackage ../servers/sql/postgresql/9.4beta3.nix { };
  postgresql94 = postgresql94beta3;

  postgresql_jdbc = callPackage ../servers/sql/postgresql/jdbc { };

  psqlodbc = callPackage ../servers/sql/postgresql/psqlodbc { };

  pyIRCt = builderDefsPackage (import ../servers/xmpp/pyIRCt) {
    inherit xmpppy pythonIRClib python makeWrapper;
  };

  pyMAILt = builderDefsPackage (import ../servers/xmpp/pyMAILt) {
    inherit xmpppy python makeWrapper fetchcvs;
  };

  qpid-cpp = callPackage ../servers/amqp/qpid-cpp { };

  rabbitmq_server = callPackage ../servers/amqp/rabbitmq-server { };

  radius = callPackage ../servers/radius { };

  redis = callPackage ../servers/nosql/redis { };

  redstore = callPackage ../servers/http/redstore { };

  restund = callPackage ../servers/restund {};

  rethinkdb = callPackage ../servers/nosql/rethinkdb {
    boost = boost155;
  };

  rippled = callPackage ../servers/rippled {
    boost = boost155;
  };

  s6 = callPackage ../servers/s6 { };

  spamassassin = callPackage ../servers/mail/spamassassin {
    inherit (perlPackages) HTMLParser NetDNS NetAddrIP DBFile
      HTTPDate MailDKIM LWP IOSocketSSL;
  };

  samba = callPackage ../servers/samba { };

  # A lightweight Samba, useful for non-Linux-based OSes.
  samba_light = lowPrio (callPackage ../servers/samba {
    pam = null;
    fam = null;
    cups = null;
    acl = null;
    openldap = null;
    # libunwind 1.0.1 is not ported to GNU/Hurd.
    libunwind = null;
  });

  serfdom = callPackage ../servers/serfdom { };

  seyren = callPackage ../servers/monitoring/seyren { };

  shishi = callPackage ../servers/shishi { };

  sipwitch = callPackage ../servers/sip/sipwitch { };

  spawn_fcgi = callPackage ../servers/http/spawn-fcgi { };

  squids = recurseIntoAttrs( import ../servers/squid/squids.nix {
    inherit fetchurl stdenv perl lib composableDerivation
      openldap pam db cyrus_sasl kerberos libcap expat libxml2 libtool
      openssl;
  });
  squid = squids.squid31; # has ipv6 support

  thttpd = callPackage ../servers/http/thttpd { };

  storm = callPackage ../servers/computing/storm { };

  tomcat5 = callPackage ../servers/http/tomcat/5.0.nix { };

  tomcat6 = callPackage ../servers/http/tomcat/6.0.nix { };

  tomcat7 = callPackage ../servers/http/tomcat/7.0.nix { };

  tomcat8 = callPackage ../servers/http/tomcat/8.0.nix { };

  tomcat_mysql_jdbc = callPackage ../servers/http/tomcat/jdbc/mysql { };

  torque = callPackage ../servers/computing/torque { };

  axis2 = callPackage ../servers/http/tomcat/axis2 { };

  unifi = callPackage ../servers/unifi { };

  virtuoso6 = callPackage ../servers/sql/virtuoso/6.x.nix { };

  virtuoso7 = callPackage ../servers/sql/virtuoso/7.x.nix { };

  virtuoso = virtuoso6;

  vsftpd = callPackage ../servers/ftp/vsftpd { };

  winstone = callPackage ../servers/http/winstone { };

  xinetd = callPackage ../servers/xinetd { };

  zookeeper = callPackage ../servers/zookeeper { };

  xquartz = callPackage ../servers/x11/xquartz { };
  quartz-wm = callPackage ../servers/x11/quartz-wm { stdenv = clangStdenv; };

  xorg = recurseIntoAttrs (import ../servers/x11/xorg/default.nix {
    inherit clangStdenv fetchurl fetchgit fetchpatch stdenv pkgconfig intltool freetype fontconfig
      libxslt expat libpng zlib perl mesa_drivers spice_protocol
      dbus libuuid openssl gperf m4 libevdev
      autoconf automake libtool xmlto asciidoc flex bison python mtdev pixman;
    mesa = mesa_noglu;
    udev = if stdenv.isLinux then udev else null;
    libdrm = if stdenv.isLinux then libdrm else null;
  });

  xorgReplacements = callPackage ../servers/x11/xorg/replacements.nix { };

  xorgVideoUnichrome = callPackage ../servers/x11/xorg/unichrome/default.nix { };

  yaws = callPackage ../servers/http/yaws { };

  zabbix = recurseIntoAttrs (import ../servers/monitoring/zabbix {
    inherit fetchurl stdenv pkgconfig postgresql curl openssl zlib;
  });

  zabbix20 = callPackage ../servers/monitoring/zabbix/2.0.nix { };
  zabbix22 = callPackage ../servers/monitoring/zabbix/2.2.nix { };


  ### OS-SPECIFIC

  afuse = callPackage ../os-specific/linux/afuse { };

  amdUcode = callPackage ../os-specific/linux/microcode/amd.nix { };

  autofs5 = callPackage ../os-specific/linux/autofs/autofs-v5.nix { };

  _915resolution = callPackage ../os-specific/linux/915resolution { };

  nfsUtils = callPackage ../os-specific/linux/nfs-utils { };

  acpi = callPackage ../os-specific/linux/acpi { };

  acpid = callPackage ../os-specific/linux/acpid { };

  acpitool = callPackage ../os-specific/linux/acpitool { };

  alienfx = callPackage ../os-specific/linux/alienfx { };

  alsaLib = callPackage ../os-specific/linux/alsa-lib { };

  alsaPlugins = callPackage ../os-specific/linux/alsa-plugins {
    jack2 = null;
  };

  alsaPluginWrapper = callPackage ../os-specific/linux/alsa-plugins/wrapper.nix { };

  alsaUtils = callPackage ../os-specific/linux/alsa-utils { };
  alsaOss = callPackage ../os-specific/linux/alsa-oss { };

  microcode2ucode = callPackage ../os-specific/linux/microcode/converter.nix { };

  microcodeIntel = callPackage ../os-specific/linux/microcode/intel.nix { };

  apparmor = callPackage ../os-specific/linux/apparmor {
    inherit (perlPackages) LocaleGettext TermReadKey RpcXML;
    bison = bison2;
  };

  atop = callPackage ../os-specific/linux/atop { };

  audit = callPackage ../os-specific/linux/audit { };

  b43Firmware_5_1_138 = callPackage ../os-specific/linux/firmware/b43-firmware/5.1.138.nix { };

  b43FirmwareCutter = callPackage ../os-specific/linux/firmware/b43-firmware-cutter { };

  batctl = callPackage ../os-specific/linux/batman-adv/batctl.nix { };

  bluez4 = callPackage ../os-specific/linux/bluez {
    pygobject = pygobject3;
  };

  bluez5 = lowPrio (callPackage ../os-specific/linux/bluez/bluez5.nix { });

  bluez = bluez4;

  inherit (pythonPackages) bedup;

  beret = callPackage ../games/beret { };

  bridge_utils = callPackage ../os-specific/linux/bridge-utils { };

  busybox = callPackage ../os-specific/linux/busybox { };

  checkpolicy = callPackage ../os-specific/linux/checkpolicy { };

  checksec = callPackage ../os-specific/linux/checksec { };

  cifs_utils = callPackage ../os-specific/linux/cifs-utils { };

  conky = callPackage ../os-specific/linux/conky {
    mpdSupport   = config.conky.mpdSupport   or true;
    x11Support   = config.conky.x11Support   or false;
    xdamage      = config.conky.xdamage      or false;
    wireless     = config.conky.wireless     or false;
    luaSupport   = config.conky.luaSupport   or false;
    rss          = config.conky.rss          or false;
    weatherMetar = config.conky.weatherMetar or false;
    weatherXoap  = config.conky.weatherXoap  or false;
  };

  conntrack_tools = callPackage ../os-specific/linux/conntrack-tools { };

  cpufrequtils = callPackage ../os-specific/linux/cpufrequtils { };

  cryopid = callPackage ../os-specific/linux/cryopid { };

  criu = callPackage ../os-specific/linux/criu { };

  cryptsetup = callPackage ../os-specific/linux/cryptsetup { };

  cramfsswap = callPackage ../os-specific/linux/cramfsswap { };

  darwin = let
    cmdline = (callPackage ../os-specific/darwin/command-line-tools {}).pure { inherit xpwn; };
  in rec {
    cctools = forceNativeDrv (callPackage ../os-specific/darwin/cctools-port {
      cross = assert crossSystem != null; crossSystem;
      inherit maloader;
      xctoolchain = xcode.toolchain;
    });

    maloader = callPackage ../os-specific/darwin/maloader {
      inherit opencflite;
    };

    opencflite = callPackage ../os-specific/darwin/opencflite {};

    xcode = callPackage ../os-specific/darwin/xcode {};

    osx_sdk = callPackage ../os-specific/darwin/osx-sdk {};
    osx_private_sdk = callPackage ../os-specific/darwin/osx-private-sdk { inherit osx_sdk; };

    security_tool = callPackage ../os-specific/darwin/security-tool { inherit osx_private_sdk; };

    cmdline_sdk   = cmdline.sdk;
    cmdline_tools = cmdline.tools;
  };

  devicemapper = lvm2;

  disk_indicator = callPackage ../os-specific/linux/disk-indicator { };

  dmidecode = callPackage ../os-specific/linux/dmidecode { };

  dmtcp = callPackage ../os-specific/linux/dmtcp { };

  dietlibc = callPackage ../os-specific/linux/dietlibc { };

  directvnc = builderDefsPackage ../os-specific/linux/directvnc {
    inherit libjpeg pkgconfig zlib directfb;
    inherit (xlibs) xproto;
  };

  dmraid = callPackage ../os-specific/linux/dmraid {
    devicemapper = devicemapper.override {enable_dmeventd = true;};
  };

  drbd = callPackage ../os-specific/linux/drbd { };

  dstat = callPackage ../os-specific/linux/dstat {
    # pythonFull includes the "curses" standard library module, for pretty
    # dstat color output
    python = pythonFull;
  };

  libossp_uuid = callPackage ../development/libraries/libossp-uuid { };

  libuuid =
    if crossSystem != null && crossSystem.config == "i586-pc-gnu"
    then (utillinux // {
      crossDrv = lib.overrideDerivation utillinux.crossDrv (args: {
        # `libblkid' fails to build on GNU/Hurd.
        configureFlags = args.configureFlags
          + " --disable-libblkid --disable-mount --disable-libmount"
          + " --disable-fsck --enable-static --disable-partx";
        doCheck = false;
        CPPFLAGS =                    # ugly hack for ugly software!
          lib.concatStringsSep " "
            (map (v: "-D${v}=4096")
                 [ "PATH_MAX" "MAXPATHLEN" "MAXHOSTNAMELEN" ]);
      });
    })
    else if stdenv.isLinux
    then utillinux
    else null;

  light = callPackage ../os-specific/linux/light { };

  lightum = callPackage ../os-specific/linux/lightum { };

  e3cfsprogs = callPackage ../os-specific/linux/e3cfsprogs { };

  ebtables = callPackage ../os-specific/linux/ebtables { };

  eject = utillinux;

  ffado = callPackage ../os-specific/linux/ffado { };

  fbterm = callPackage ../os-specific/linux/fbterm { };

  firejail = callPackage ../os-specific/linux/firejail {};

  fuse = callPackage ../os-specific/linux/fuse { };

  fxload = callPackage ../os-specific/linux/fxload { };

  gfxtablet = callPackage ../os-specific/linux/gfxtablet {};

  gpm = callPackage ../servers/gpm { };

  gradm = callPackage ../os-specific/linux/gradm {
    flex = flex_2_5_35;
  };

  hdparm = callPackage ../os-specific/linux/hdparm { };

  hibernate = callPackage ../os-specific/linux/hibernate { };

  hostapd = callPackage ../os-specific/linux/hostapd { };

  htop =
    if stdenv.isLinux then
      callPackage ../os-specific/linux/htop { }
    else if stdenv.isDarwin then
      callPackage ../os-specific/darwin/htop { }
    else null;

  # GNU/Hurd core packages.
  gnu = recurseIntoAttrs (callPackage ../os-specific/gnu {
    inherit platform crossSystem;
  });

  hwdata = callPackage ../os-specific/linux/hwdata { };

  i7z = callPackage ../os-specific/linux/i7z { };

  ifplugd = callPackage ../os-specific/linux/ifplugd { };

  iomelt = callPackage ../os-specific/linux/iomelt { };

  iotop = callPackage ../os-specific/linux/iotop { };

  iproute = callPackage ../os-specific/linux/iproute { };

  iputils = callPackage ../os-specific/linux/iputils {
    sp = spCompat;
    inherit (perlPackages) SGMLSpm;
  };

  iptables = callPackage ../os-specific/linux/iptables { };

  iw = callPackage ../os-specific/linux/iw { };

  jujuutils = callPackage ../os-specific/linux/jujuutils { };

  kbd = callPackage ../os-specific/linux/kbd { };

  kmscon = callPackage ../os-specific/linux/kmscon { };

  latencytop = callPackage ../os-specific/linux/latencytop { };

  ldm = callPackage ../os-specific/linux/ldm { };

  libaio = callPackage ../os-specific/linux/libaio { };

  libatasmart = callPackage ../os-specific/linux/libatasmart { };

  libcgroup = callPackage ../os-specific/linux/libcgroup { };

  libnl = callPackage ../os-specific/linux/libnl { };

  linuxConsoleTools = callPackage ../os-specific/linux/consoletools { };

  # -- Linux kernel expressions ------------------------------------------------

  linuxHeaders = linuxHeaders_3_7;

  linuxHeaders24Cross = forceNativeDrv (import ../os-specific/linux/kernel-headers/2.4.nix {
    inherit stdenv fetchurl perl;
    cross = assert crossSystem != null; crossSystem;
  });

  linuxHeaders26Cross = forceNativeDrv (import ../os-specific/linux/kernel-headers/2.6.32.nix {
    inherit stdenv fetchurl perl;
    cross = assert crossSystem != null; crossSystem;
  });

  linuxHeaders_3_7 = callPackage ../os-specific/linux/kernel-headers/3.7.nix { };

  linuxHeaders_3_14 = callPackage ../os-specific/linux/kernel-headers/3.14.nix { };

  # We can choose:
  linuxHeadersCrossChooser = ver : if ver == "2.4" then linuxHeaders24Cross
    else if ver == "2.6" then linuxHeaders26Cross
    else throw "Unknown linux kernel version";

  linuxHeadersCross = assert crossSystem != null;
    linuxHeadersCrossChooser crossSystem.platform.kernelMajor;

  kernelPatches = callPackage ../os-specific/linux/kernel/patches.nix { };

  linux_3_2 = makeOverridable (import ../os-specific/linux/kernel/linux-3.2.nix) {
    inherit fetchurl stdenv perl buildLinux;
    kernelPatches = [];
  };

  linux_3_4 = makeOverridable (import ../os-specific/linux/kernel/linux-3.4.nix) {
    inherit fetchurl stdenv perl buildLinux;
    kernelPatches = lib.optionals ((platform.kernelArch or null) == "mips")
      [ kernelPatches.mips_fpureg_emu
        kernelPatches.mips_fpu_sigill
      ];
  };

  linux_3_6_rpi = makeOverridable (import ../os-specific/linux/kernel/linux-rpi-3.6.nix) {
    inherit fetchurl stdenv perl buildLinux;
  };

  linux_3_10 = makeOverridable (import ../os-specific/linux/kernel/linux-3.10.nix) {
    inherit fetchurl stdenv perl buildLinux;
    kernelPatches = lib.optionals ((platform.kernelArch or null) == "mips")
      [ kernelPatches.mips_fpureg_emu
        kernelPatches.mips_fpu_sigill
        kernelPatches.mips_ext3_n32
      ];
  };

  linux_3_12 = makeOverridable (import ../os-specific/linux/kernel/linux-3.12.nix) {
    inherit fetchurl stdenv perl buildLinux;
    kernelPatches = lib.optionals ((platform.kernelArch or null) == "mips")
      [ kernelPatches.mips_fpureg_emu
        kernelPatches.mips_fpu_sigill
        kernelPatches.mips_ext3_n32
      ];
  };

  linux_3_14 = makeOverridable (import ../os-specific/linux/kernel/linux-3.14.nix) {
    inherit fetchurl stdenv perl buildLinux;
    kernelPatches = lib.optionals ((platform.kernelArch or null) == "mips")
      [ kernelPatches.mips_fpureg_emu
        kernelPatches.mips_fpu_sigill
        kernelPatches.mips_ext3_n32
      ];
  };

  linux_3_16 = makeOverridable (import ../os-specific/linux/kernel/linux-3.16.nix) {
    inherit fetchurl stdenv perl buildLinux;
    kernelPatches = lib.optionals ((platform.kernelArch or null) == "mips")
      [ kernelPatches.mips_fpureg_emu
        kernelPatches.mips_fpu_sigill
        kernelPatches.mips_ext3_n32
      ];
  };

  linux_3_17 = makeOverridable (import ../os-specific/linux/kernel/linux-3.17.nix) {
    inherit fetchurl stdenv perl buildLinux;
    kernelPatches = lib.optionals ((platform.kernelArch or null) == "mips")
      [ kernelPatches.mips_fpureg_emu
        kernelPatches.mips_fpu_sigill
        kernelPatches.mips_ext3_n32
      ];
  };

  linux_testing = makeOverridable (import ../os-specific/linux/kernel/linux-testing.nix) {
    inherit fetchurl stdenv perl buildLinux;
    kernelPatches = lib.optionals ((platform.kernelArch or null) == "mips")
      [ kernelPatches.mips_fpureg_emu
        kernelPatches.mips_fpu_sigill
        kernelPatches.mips_ext3_n32
      ];
  };

  /* grsec configuration

     We build several flavors of 'default' grsec kernels. These are
     built by default with Hydra. If the user selects a matching
     'default' flavor, then the pre-canned package set can be
     chosen. Typically, users will make very basic choices like
     'security' + 'server' or 'performance' + 'desktop' with
     virtualisation support. These will then be picked.

     Note: Xen guest kernels are included for e.g. NixOps deployments
     to EC2, where Xen is the Hypervisor.
  */

  grFlavors = import ../build-support/grsecurity/flavors.nix;

  mkGrsecurity = opts:
    (import ../build-support/grsecurity {
      grsecOptions = opts;
      inherit pkgs lib;
    });

  grKernel  = opts: (mkGrsecurity opts).grsecKernel;
  grPackage = opts: recurseIntoAttrs (mkGrsecurity opts).grsecPackage;

  # Stable kernels
  linux_grsec_stable_desktop    = grKernel grFlavors.linux_grsec_stable_desktop;
  linux_grsec_stable_server     = grKernel grFlavors.linux_grsec_stable_server;
  linux_grsec_stable_server_xen = grKernel grFlavors.linux_grsec_stable_server_xen;

  # Testing kernels
  linux_grsec_testing_desktop = grKernel grFlavors.linux_grsec_testing_desktop;
  linux_grsec_testing_server  = grKernel grFlavors.linux_grsec_testing_server;
  linux_grsec_testing_server_xen = grKernel grFlavors.linux_grsec_testing_server_xen;

  /* Linux kernel modules are inherently tied to a specific kernel.  So
     rather than provide specific instances of those packages for a
     specific kernel, we have a function that builds those packages
     for a specific kernel.  This function can then be called for
     whatever kernel you're using. */

  linuxPackagesFor = kernel: self: let callPackage = newScope self; in {
    inherit kernel;

    acpi_call = callPackage ../os-specific/linux/acpi-call {};

    batman_adv = callPackage ../os-specific/linux/batman-adv {};

    bbswitch = callPackage ../os-specific/linux/bbswitch {};

    ati_drivers_x11 = callPackage ../os-specific/linux/ati-drivers { };

    blcr = callPackage ../os-specific/linux/blcr { };

    cryptodev = callPackage ../os-specific/linux/cryptodev { };

    cpupower = callPackage ../os-specific/linux/cpupower { };

    e1000e = callPackage ../os-specific/linux/e1000e {};

    v4l2loopback = callPackage ../os-specific/linux/v4l2loopback { };

    frandom = callPackage ../os-specific/linux/frandom { };

    ktap = callPackage ../os-specific/linux/ktap { };

    lttng-modules = callPackage ../os-specific/linux/lttng-modules { };

    broadcom_sta = callPackage ../os-specific/linux/broadcom-sta/default.nix { };

    nvidiabl = callPackage ../os-specific/linux/nvidiabl { };

    nvidia_x11 = self.nvidia_x11_legacy340;

    nvidia_x11_legacy173 = callPackage ../os-specific/linux/nvidia-x11/legacy173.nix { };
    nvidia_x11_legacy304 = callPackage ../os-specific/linux/nvidia-x11/legacy304.nix { };
    nvidia_x11_legacy340 = callPackage ../os-specific/linux/nvidia-x11/legacy340.nix { };

    openafsClient = callPackage ../servers/openafs-client { };

    openiscsi = callPackage ../os-specific/linux/open-iscsi { };

    wis_go7007 = callPackage ../os-specific/linux/wis-go7007 { };

    kernelHeaders = callPackage ../os-specific/linux/kernel-headers { };

    klibc = callPackage ../os-specific/linux/klibc { };

    klibcShrunk = lowPrio (callPackage ../os-specific/linux/klibc/shrunk.nix { });


    /* compiles but has to be integrated into the kernel somehow
       Let's have it uncommented and finish it..
    */
    ndiswrapper = callPackage ../os-specific/linux/ndiswrapper { };

    netatop = callPackage ../os-specific/linux/netatop { };

    perf = callPackage ../os-specific/linux/kernel/perf.nix { };

    prl-tools = callPackage ../os-specific/linux/prl-tools { };

    psmouse_alps = callPackage ../os-specific/linux/psmouse-alps { };

    seturgent = callPackage ../os-specific/linux/seturgent { };

    spl = callPackage ../os-specific/linux/spl { };
    spl_git = callPackage ../os-specific/linux/spl/git.nix { };

    sysdig = callPackage ../os-specific/linux/sysdig {};

    tp_smapi = callPackage ../os-specific/linux/tp_smapi { };

    v86d = callPackage ../os-specific/linux/v86d { };

    virtualbox = callPackage ../applications/virtualization/virtualbox {
      stdenv = stdenv_32bit;
      inherit (gnome) libIDL;
      enableExtensionPack = config.virtualbox.enableExtensionPack or false;
      pulseSupport = config.pulseaudio or false;
    };

    virtualboxGuestAdditions = callPackage ../applications/virtualization/virtualbox/guest-additions { };

    zfs = callPackage ../os-specific/linux/zfs { };
    zfs_git = callPackage ../os-specific/linux/zfs/git.nix { };
  };

  # The current default kernel / kernel modules.
  linux = linuxPackages.kernel;
  linuxPackages = linuxPackages_3_14;

  # Update this when adding the newest kernel major version!
  linux_latest = pkgs.linux_3_17;
  linuxPackages_latest = pkgs.linuxPackages_3_17;

  # Build the kernel modules for the some of the kernels.
  linuxPackages_3_2 = recurseIntoAttrs (linuxPackagesFor pkgs.linux_3_2 linuxPackages_3_2);
  linuxPackages_3_4 = recurseIntoAttrs (linuxPackagesFor pkgs.linux_3_4 linuxPackages_3_4);
  linuxPackages_3_6_rpi = linuxPackagesFor pkgs.linux_3_6_rpi linuxPackages_3_6_rpi;
  linuxPackages_3_10 = recurseIntoAttrs (linuxPackagesFor pkgs.linux_3_10 linuxPackages_3_10);
  linuxPackages_3_10_tuxonice = linuxPackagesFor pkgs.linux_3_10_tuxonice linuxPackages_3_10_tuxonice;
  linuxPackages_3_12 = recurseIntoAttrs (linuxPackagesFor pkgs.linux_3_12 linuxPackages_3_12);
  linuxPackages_3_14 = recurseIntoAttrs (linuxPackagesFor pkgs.linux_3_14 linuxPackages_3_14);
  linuxPackages_3_16 = recurseIntoAttrs (linuxPackagesFor pkgs.linux_3_16 linuxPackages_3_16);
  linuxPackages_3_17 = recurseIntoAttrs (linuxPackagesFor pkgs.linux_3_17 linuxPackages_3_17);
  linuxPackages_testing = recurseIntoAttrs (linuxPackagesFor pkgs.linux_testing linuxPackages_testing);

  # grsecurity flavors
  # Stable kernels
  linuxPackages_grsec_stable_desktop    = grPackage grFlavors.linux_grsec_stable_desktop;
  linuxPackages_grsec_stable_server     = grPackage grFlavors.linux_grsec_stable_server;
  linuxPackages_grsec_stable_server_xen = grPackage grFlavors.linux_grsec_stable_server_xen;

  # Testing kernels
  linuxPackages_grsec_testing_desktop = grPackage grFlavors.linux_grsec_testing_desktop;
  linuxPackages_grsec_testing_server  = grPackage grFlavors.linux_grsec_testing_server;
  linuxPackages_grsec_testing_server_xen = grPackage grFlavors.linux_grsec_testing_server_xen;

  # A function to build a manually-configured kernel
  linuxManualConfig = pkgs.buildLinux;
  buildLinux = import ../os-specific/linux/kernel/manual-config.nix {
    inherit (pkgs) stdenv runCommand nettools bc perl kmod writeTextFile ubootChooser;
  };

  keyutils = callPackage ../os-specific/linux/keyutils { };

  libselinux = callPackage ../os-specific/linux/libselinux { };

  libsemanage = callPackage ../os-specific/linux/libsemanage { };

  libraw = callPackage ../development/libraries/libraw { };

  libraw1394 = callPackage ../development/libraries/libraw1394 { };

  libsexy = callPackage ../development/libraries/libsexy { };

  libsepol = callPackage ../os-specific/linux/libsepol { };

  libsmbios = callPackage ../os-specific/linux/libsmbios { };

  lm_sensors = callPackage ../os-specific/linux/lm-sensors { };

  lockdep = callPackage ../os-specific/linux/lockdep { };

  lsiutil = callPackage ../os-specific/linux/lsiutil { };

  kmod = callPackage ../os-specific/linux/kmod { };

  kmod-blacklist-ubuntu = callPackage ../os-specific/linux/kmod-blacklist-ubuntu { };

  kvm = qemu_kvm;

  libcap = callPackage ../os-specific/linux/libcap { };

  libcap_progs = callPackage ../os-specific/linux/libcap/progs.nix { };

  libcap_pam = callPackage ../os-specific/linux/libcap/pam.nix { };

  libcap_manpages = callPackage ../os-specific/linux/libcap/man.nix { };

  libcap_ng = callPackage ../os-specific/linux/libcap-ng { };

  libnscd = callPackage ../os-specific/linux/libnscd { };

  libnotify = callPackage ../development/libraries/libnotify { };

  libvolume_id = callPackage ../os-specific/linux/libvolume_id { };

  lsscsi = callPackage ../os-specific/linux/lsscsi { };

  lvm2 = callPackage ../os-specific/linux/lvm2 { };

  mdadm = callPackage ../os-specific/linux/mdadm { };

  mingetty = callPackage ../os-specific/linux/mingetty { };

  module_init_tools = callPackage ../os-specific/linux/module-init-tools { };

  aggregateModules = modules:
    callPackage ../os-specific/linux/kmod/aggregator.nix {
      inherit modules;
    };

  multipath_tools = callPackage ../os-specific/linux/multipath-tools { };

  musl = callPackage ../os-specific/linux/musl { };

  nettools = callPackage ../os-specific/linux/net-tools { };

  neverball = callPackage ../games/neverball {
    libpng = libpng15;
  };

  nftables = callPackage ../os-specific/linux/nftables { };

  numactl = callPackage ../os-specific/linux/numactl { };

  gocode = callPackage ../development/tools/gocode { };

  gotags = callPackage ../development/tools/gotags { };

  golint = callPackage ../development/tools/golint { };

  gogoclient = callPackage ../os-specific/linux/gogoclient { };

  nss_ldap = callPackage ../os-specific/linux/nss_ldap { };

  pam = callPackage ../os-specific/linux/pam { };

  # pam_bioapi ( see http://www.thinkwiki.org/wiki/How_to_enable_the_fingerprint_reader )

  pam_ccreds = callPackage ../os-specific/linux/pam_ccreds { };

  pam_console = callPackage ../os-specific/linux/pam_console {
    libtool = libtool_1_5;
  };

  pam_devperm = callPackage ../os-specific/linux/pam_devperm { };

  pam_krb5 = callPackage ../os-specific/linux/pam_krb5 { };

  pam_ldap = callPackage ../os-specific/linux/pam_ldap { };

  pam_login = callPackage ../os-specific/linux/pam_login { };

  pam_mount = callPackage ../os-specific/linux/pam_mount { };

  pam_ssh_agent_auth = callPackage ../os-specific/linux/pam_ssh_agent_auth { };

  pam_usb = callPackage ../os-specific/linux/pam_usb { };

  paxctl = callPackage ../os-specific/linux/paxctl { };

  pax-utils = callPackage ../os-specific/linux/pax-utils { };

  pcmciaUtils = callPackage ../os-specific/linux/pcmciautils {
    firmware = config.pcmciaUtils.firmware or [];
    config = config.pcmciaUtils.config or null;
  };

  plymouth = callPackage ../os-specific/linux/plymouth {
    automake = automake113x;
  };

  pmount = callPackage ../os-specific/linux/pmount { };

  pmutils = callPackage ../os-specific/linux/pm-utils { };

  pmtools = callPackage ../os-specific/linux/pmtools { };

  policycoreutils = callPackage ../os-specific/linux/policycoreutils { };

  powertop = callPackage ../os-specific/linux/powertop { };

  prayer = callPackage ../servers/prayer { };

  procps = procps-ng;

  procps-old = lowPrio (callPackage ../os-specific/linux/procps { });

  procps-ng = callPackage ../os-specific/linux/procps-ng { };

  watch = callPackage ../os-specific/linux/procps/watch.nix { };

  qemu_kvm = lowPrio (qemu.override { x86Only = true; });

  firmwareLinuxNonfree = callPackage ../os-specific/linux/firmware/firmware-linux-nonfree { };

  radeontools = callPackage ../os-specific/linux/radeontools { };

  raspberrypifw = callPackage ../os-specific/linux/firmware/raspberrypi {};

  regionset = callPackage ../os-specific/linux/regionset { };

  rfkill = callPackage ../os-specific/linux/rfkill { };

  rfkill_udev = callPackage ../os-specific/linux/rfkill/udev.nix { };

  rtkit = callPackage ../os-specific/linux/rtkit { };

  sdparm = callPackage ../os-specific/linux/sdparm { };

  sepolgen = callPackage ../os-specific/linux/sepolgen { };

  setools = callPackage ../os-specific/linux/setools { };

  shadow = callPackage ../os-specific/linux/shadow { };

  smem = callPackage ../os-specific/linux/smem { };

  statifier = builderDefsPackage (import ../os-specific/linux/statifier) { };

  sysdig = callPackage ../os-specific/linux/sysdig {
    kernel = null;
  }; # pkgs.sysdig is a client, for a driver look at linuxPackagesFor

  sysfsutils = callPackage ../os-specific/linux/sysfsutils { };

  sysprof = callPackage ../development/tools/profiling/sysprof {
    inherit (gnome) libglade;
  };

  # Provided with sysfsutils.
  libsysfs = sysfsutils;
  systool = sysfsutils;

  sysklogd = callPackage ../os-specific/linux/sysklogd { };

  syslinux = callPackage ../os-specific/linux/syslinux { };

  sysstat = callPackage ../os-specific/linux/sysstat { };

  systemd = callPackage ../os-specific/linux/systemd {
    linuxHeaders = linuxHeaders_3_14;
  };

  systemtap = callPackage ../development/tools/profiling/systemtap {
    inherit (gnome) libglademm;
  };

  # In nixos, you can set systemd.package = pkgs.systemd_with_lvm2 to get
  # LVM2 working in systemd.
  systemd_with_lvm2 = pkgs.lib.overrideDerivation pkgs.systemd (p: {
      name = p.name + "-with-lvm2";
      postInstall = p.postInstall + ''
        cp "${pkgs.lvm2}/lib/systemd/system-generators/"* $out/lib/systemd/system-generators
      '';
  });

  sysvinit = callPackage ../os-specific/linux/sysvinit { };

  sysvtools = callPackage ../os-specific/linux/sysvinit {
    withoutInitTools = true;
  };

  # FIXME: `tcp-wrapper' is actually not OS-specific.
  tcp_wrappers = callPackage ../os-specific/linux/tcp-wrappers { };

  trackballs = callPackage ../games/trackballs {
    debug = false;
    guile = guile_1_8;
  };

  tunctl = callPackage ../os-specific/linux/tunctl { };

  ubootChooser = name : if name == "upstream" then ubootUpstream
    else if name == "sheevaplug" then ubootSheevaplug
    else if name == "guruplug" then ubootGuruplug
    else if name == "nanonote" then ubootNanonote
    else throw "Unknown uboot";

  ubootUpstream = callPackage ../misc/uboot { };

  ubootSheevaplug = callPackage ../misc/uboot/sheevaplug.nix { };

  ubootNanonote = callPackage ../misc/uboot/nanonote.nix { };

  ubootGuruplug = callPackage ../misc/uboot/guruplug.nix { };

  uclibc = callPackage ../os-specific/linux/uclibc { };

  uclibcCross = lowPrio (callPackage ../os-specific/linux/uclibc {
    inherit fetchurl stdenv libiconv;
    linuxHeaders = linuxHeadersCross;
    gccCross = gccCrossStageStatic;
    cross = assert crossSystem != null; crossSystem;
  });

  udev145 = callPackage ../os-specific/linux/udev/145.nix { };
  udev = pkgs.systemd;
  eudev = callPackage ../os-specific/linux/eudev {};

  udisks1 = callPackage ../os-specific/linux/udisks/1-default.nix { };
  udisks2 = callPackage ../os-specific/linux/udisks/2-default.nix { };
  udisks = udisks1;

  udisks_glue = callPackage ../os-specific/linux/udisks-glue { };

  untie = callPackage ../os-specific/linux/untie { };

  upower = callPackage ../os-specific/linux/upower { };

  upower_99 = callPackage ../os-specific/linux/upower/0.99.nix { };

  upstart = callPackage ../os-specific/linux/upstart { };

  usbutils = callPackage ../os-specific/linux/usbutils { };

  usermount = callPackage ../os-specific/linux/usermount { };

  utillinux = lowPrio (callPackage ../os-specific/linux/util-linux {
    ncurses = null;
    perl = null;
  });

  utillinuxCurses = utillinux.override {
    inherit ncurses perl;
  };

  v4l_utils = callPackage ../os-specific/linux/v4l-utils {
    withQt4 = true;
  };

  windows = rec {
    cygwinSetup = callPackage ../os-specific/windows/cygwin-setup { };

    jom = callPackage ../os-specific/windows/jom { };

    w32api = callPackage ../os-specific/windows/w32api {
      gccCross = gccCrossStageStatic;
      binutilsCross = binutilsCross;
    };

    w32api_headers = w32api.override {
      onlyHeaders = true;
    };

    mingw_runtime = callPackage ../os-specific/windows/mingwrt {
      gccCross = gccCrossMingw2;
      binutilsCross = binutilsCross;
    };

    mingw_runtime_headers = mingw_runtime.override {
      onlyHeaders = true;
    };

    mingw_headers1 = buildEnv {
      name = "mingw-headers-1";
      paths = [ w32api_headers mingw_runtime_headers ];
    };

    mingw_headers2 = buildEnv {
      name = "mingw-headers-2";
      paths = [ w32api mingw_runtime_headers ];
    };

    mingw_headers3 = buildEnv {
      name = "mingw-headers-3";
      paths = [ w32api mingw_runtime ];
    };

    mingw_w64 = callPackage ../os-specific/windows/mingw-w64 {
      gccCross = gccCrossStageStatic;
      binutilsCross = binutilsCross;
    };

    mingw_w64_headers = callPackage ../os-specific/windows/mingw-w64 {
      onlyHeaders = true;
    };

    mingw_w64_pthreads = callPackage ../os-specific/windows/mingw-w64 {
      onlyPthreads = true;
    };

    pthreads = callPackage ../os-specific/windows/pthread-w32 {
      mingw_headers = mingw_headers3;
    };

    wxMSW = callPackage ../os-specific/windows/wxMSW-2.8 { };
  };

  wesnoth = callPackage ../games/wesnoth {
    lua = lua5;
  };

  wirelesstools = callPackage ../os-specific/linux/wireless-tools { };

  wpa_supplicant = callPackage ../os-specific/linux/wpa_supplicant { };

  wpa_supplicant_gui = callPackage ../os-specific/linux/wpa_supplicant/gui.nix { };

  xf86_input_mtrack = callPackage ../os-specific/linux/xf86-input-mtrack {
    inherit (xorg) utilmacros xproto inputproto xorgserver;
  };

  xf86_input_multitouch =
    callPackage ../os-specific/linux/xf86-input-multitouch { };

  xf86_input_wacom = callPackage ../os-specific/linux/xf86-input-wacom { };

  xf86_video_nested = callPackage ../os-specific/linux/xf86-video-nested {
    inherit (xorg) fontsproto renderproto utilmacros xorgserver;
  };

  xf86_video_nouveau = xorg.xf86videonouveau;

  xmoto = builderDefsPackage (import ../games/xmoto) {
    inherit chipmunk sqlite curl zlib bzip2 libjpeg libpng
      freeglut mesa SDL SDL_mixer SDL_image SDL_net SDL_ttf
      lua5 ode libxdg_basedir libxml2;
  };

  xorg_sys_opengl = callPackage ../os-specific/linux/opengl/xorg-sys { };

  zd1211fw = callPackage ../os-specific/linux/firmware/zd1211 { };


  ### DATA

  andagii = callPackage ../data/fonts/andagii {};

  anonymousPro = callPackage ../data/fonts/anonymous-pro {};

  arkpandora_ttf = builderDefsPackage (import ../data/fonts/arkpandora) { };

  aurulent-sans = callPackage ../data/fonts/aurulent-sans { };

  baekmuk-ttf = callPackage ../data/fonts/baekmuk-ttf { };

  bakoma_ttf = callPackage ../data/fonts/bakoma-ttf { };

  cacert = callPackage ../data/misc/cacert { };

  cantarell_fonts = callPackage ../data/fonts/cantarell-fonts { };

  comic-neue = callPackage ../data/fonts/comic-neue { };

  corefonts = callPackage ../data/fonts/corefonts { };

  wrapFonts = paths : ((import ../data/fonts/fontWrap) {
    inherit fetchurl stdenv builderDefs paths;
    inherit (xorg) mkfontdir mkfontscale;
  });

  clearlyU = callPackage ../data/fonts/clearlyU { };

  cm_unicode = callPackage ../data/fonts/cm-unicode {};

  dejavu_fonts = callPackage ../data/fonts/dejavu-fonts {
    inherit (perlPackages) FontTTF;
  };

  docbook5 = callPackage ../data/sgml+xml/schemas/docbook-5.0 { };

  docbook_sgml_dtd_31 = callPackage ../data/sgml+xml/schemas/sgml-dtd/docbook/3.1.nix { };

  docbook_sgml_dtd_41 = callPackage ../data/sgml+xml/schemas/sgml-dtd/docbook/4.1.nix { };

  docbook_xml_dtd_412 = callPackage ../data/sgml+xml/schemas/xml-dtd/docbook/4.1.2.nix { };

  docbook_xml_dtd_42 = callPackage ../data/sgml+xml/schemas/xml-dtd/docbook/4.2.nix { };

  docbook_xml_dtd_43 = callPackage ../data/sgml+xml/schemas/xml-dtd/docbook/4.3.nix { };

  docbook_xml_dtd_45 = callPackage ../data/sgml+xml/schemas/xml-dtd/docbook/4.5.nix { };

  docbook_xml_ebnf_dtd = callPackage ../data/sgml+xml/schemas/xml-dtd/docbook-ebnf { };

  docbook_xml_xslt = docbook_xsl;

  docbook_xsl = callPackage ../data/sgml+xml/stylesheets/xslt/docbook-xsl { };

  docbook5_xsl = docbook_xsl_ns;

  docbook_xsl_ns = callPackage ../data/sgml+xml/stylesheets/xslt/docbook-xsl-ns { };

  dosemu_fonts = callPackage ../data/fonts/dosemu-fonts { };

  eb-garamond = callPackage ../data/fonts/eb-garamond { };

  fira = callPackage ../data/fonts/fira { };

  freefont_ttf = callPackage ../data/fonts/freefont-ttf { };

  freepats = callPackage ../data/misc/freepats { };

  gentium = callPackage ../data/fonts/gentium {};

  gnome_user_docs = callPackage ../data/documentation/gnome-user-docs { };

  inherit (gnome3) gsettings_desktop_schemas;

  hicolor_icon_theme = callPackage ../data/icons/hicolor-icon-theme { };

  inconsolata = callPackage ../data/fonts/inconsolata {};

  ipafont = callPackage ../data/fonts/ipafont {};

  junicode = callPackage ../data/fonts/junicode { };

  kochi-substitute = callPackage ../data/fonts/kochi-substitute {};

  kochi-substitute-naga10 = callPackage ../data/fonts/kochi-substitute-naga10 {};

  liberation_ttf_from_source = callPackage ../data/fonts/redhat-liberation-fonts { };
  liberation_ttf_binary = callPackage ../data/fonts/redhat-liberation-fonts/binary.nix { };
  liberation_ttf = liberation_ttf_binary;

  libertine = builderDefsPackage (import ../data/fonts/libertine) {
    inherit fetchurl fontforge lib;
  };

  lmmath = callPackage ../data/fonts/lmodern/lmmath.nix {};

  lmodern = callPackage ../data/fonts/lmodern { };

  lohit-fonts = callPackage ../data/fonts/lohit-fonts { };

  manpages = callPackage ../data/documentation/man-pages { };

  meslo-lg = callPackage ../data/fonts/meslo-lg {};

  miscfiles = callPackage ../data/misc/miscfiles { };

  mobile_broadband_provider_info = callPackage ../data/misc/mobile-broadband-provider-info { };

  mph_2b_damase = callPackage ../data/fonts/mph-2b-damase { };

  nafees = callPackage ../data/fonts/nafees { };

  oldstandard = callPackage ../data/fonts/oldstandard { };

  opensans-ttf = callPackage ../data/fonts/opensans-ttf { };

  poly = callPackage ../data/fonts/poly { };

  posix_man_pages = callPackage ../data/documentation/man-pages-posix { };

  proggyfonts = callPackage ../data/fonts/proggyfonts { };

  pthreadmanpages = callPackage ../data/documentation/pthread-man-pages { };

  shared_mime_info = callPackage ../data/misc/shared-mime-info { };

  shared_desktop_ontologies = callPackage ../data/misc/shared-desktop-ontologies { };

  stdmanpages = callPackage ../data/documentation/std-man-pages { };

  stix-otf = callPackage ../data/fonts/stix-otf { };

  symbola = callPackage ../data/fonts/symbola { };

  iana_etc = callPackage ../data/misc/iana-etc { };

  poppler_data = callPackage ../data/misc/poppler-data { };

  r3rs = callPackage ../data/documentation/rnrs/r3rs.nix { };

  r4rs = callPackage ../data/documentation/rnrs/r4rs.nix { };

  r5rs = callPackage ../data/documentation/rnrs/r5rs.nix { };

  hasklig = callPackage ../data/fonts/hasklig {};

  source-code-pro = callPackage ../data/fonts/source-code-pro {};

  source-sans-pro = callPackage ../data/fonts/source-sans-pro { };

  source-serif-pro = callPackage ../data/fonts/source-serif-pro { };

  source-han-sans-japanese = callPackage ../data/fonts/source-han-sans/japanese.nix {};
  source-han-sans-korean = callPackage ../data/fonts/source-han-sans/korean.nix {};
  source-han-sans-simplified-chinese = callPackage ../data/fonts/source-han-sans/simplified-chinese.nix {};
  source-han-sans-traditional-chinese = callPackage ../data/fonts/source-han-sans/traditional-chinese.nix {};

  tango-icon-theme = callPackage ../data/icons/tango-icon-theme { };

  themes = name: import (../data/misc/themes + ("/" + name + ".nix")) {
    inherit fetchurl;
  };

  theano = callPackage ../data/fonts/theano { };

  tempora_lgc = callPackage ../data/fonts/tempora-lgc { };

  terminus_font = callPackage ../data/fonts/terminus-font { };

  tipa = callPackage ../data/fonts/tipa { };

  ttf_bitstream_vera = callPackage ../data/fonts/ttf-bitstream-vera { };

  tzdata = callPackage ../data/misc/tzdata { };

  ubuntu_font_family = callPackage ../data/fonts/ubuntu-font-family { };

  ucsFonts = callPackage ../data/fonts/ucs-fonts { };

  unifont = callPackage ../data/fonts/unifont { };

  vistafonts = callPackage ../data/fonts/vista-fonts { };

  wqy_microhei = callPackage ../data/fonts/wqy-microhei { };

  wqy_zenhei = callPackage ../data/fonts/wqy-zenhei { };

  xhtml1 = callPackage ../data/sgml+xml/schemas/xml-dtd/xhtml1 { };

  xkeyboard_config = xorg.xkeyboardconfig;


  ### APPLICATIONS

  a2jmidid = callPackage ../applications/audio/a2jmidid { };

  aangifte2006 = callPackage_i686 ../applications/taxes/aangifte-2006 { };

  aangifte2007 = callPackage_i686 ../applications/taxes/aangifte-2007 { };

  aangifte2008 = callPackage_i686 ../applications/taxes/aangifte-2008 { };

  aangifte2009 = callPackage_i686 ../applications/taxes/aangifte-2009 { };

  aangifte2010 = callPackage_i686 ../applications/taxes/aangifte-2010 { };

  aangifte2011 = callPackage_i686 ../applications/taxes/aangifte-2011 { };

  aangifte2012 = callPackage_i686 ../applications/taxes/aangifte-2012 { };

  aangifte2013 = callPackage_i686 ../applications/taxes/aangifte-2013 { };

  abcde = callPackage ../applications/audio/abcde {
    inherit (perlPackages) DigestSHA MusicBrainz MusicBrainzDiscID;
    libcdio = libcdio082;
  };

  abiword = callPackage ../applications/office/abiword {
    inherit (gnome) libglade libgnomecanvas;
  };

  abook = callPackage ../applications/misc/abook { };

  adobe-reader = callPackage_i686 ../applications/misc/adobe-reader { };

  aewan = callPackage ../applications/editors/aewan { };

  afterstep = callPackage ../applications/window-managers/afterstep {
    inherit (xlibs) libX11 libXext libICE;
    fltk = fltk13;
    gtk = gtk2;
  };

  alchemy = callPackage ../applications/graphics/alchemy { };

  alock = callPackage ../misc/screensavers/alock { };

  alpine = callPackage ../applications/networking/mailreaders/alpine {};
  realpine = callPackage ../applications/networking/mailreaders/realpine {};

  ams-lv2 = callPackage ../applications/audio/ams-lv2 { };

  amsn = callPackage ../applications/networking/instant-messengers/amsn { };

  antiword = callPackage ../applications/office/antiword {};

  ardour = ardour3;

  ardour3 =  lowPrio (callPackage ../applications/audio/ardour {
    inherit (gnome) libgnomecanvas libgnomecanvasmm;
  });

  arora = callPackage ../applications/networking/browsers/arora { };

  atom = callPackage ../applications/editors/atom {
    gconf = gnome.GConf;
  };

  aseprite = callPackage ../applications/editors/aseprite {
    giflib = giflib_4_1;
  };

  audacious = callPackage ../applications/audio/audacious { };

  audacity = callPackage ../applications/audio/audacity {
    ffmpeg = ffmpeg_0_10;
  };

  milkytracker = callPackage ../applications/audio/milkytracker { };

  aumix = callPackage ../applications/audio/aumix {
    gtkGUI = false;
  };

  autopanosiftc = callPackage ../applications/graphics/autopanosiftc { };

  avidemux = callPackage ../applications/video/avidemux { };

  avogadro = callPackage ../applications/science/chemistry/avogadro {
    eigen = eigen2;
  };

  avrdudess = callPackage ../applications/misc/avrdudess { };

  avxsynth = callPackage ../applications/video/avxsynth { };

  awesome-3-4 = callPackage ../applications/window-managers/awesome/3.4.nix {
    cairo = cairo.override { xcbSupport = true; };
    lua = lua5_1;
  };
  awesome-3-5 = callPackage ../applications/window-managers/awesome {
    cairo = cairo.override { xcbSupport = true; };
  };
  awesome = awesome-3-5;

  inherit (gnome3) baobab;

  backintime-common = callPackage ../applications/networking/sync/backintime/common.nix { };

  backintime-gnome = callPackage ../applications/networking/sync/backintime/gnome.nix { };

  backintime = backintime-gnome;

  bar = callPackage ../applications/window-managers/bar { };

  baresip = callPackage ../applications/networking/instant-messengers/baresip {
    ffmpeg = ffmpeg_1;
  };

  batik = callPackage ../applications/graphics/batik { };

  batti = callPackage ../applications/misc/batti { };

  bazaar = callPackage ../applications/version-management/bazaar { };

  bazaarTools = builderDefsPackage (import ../applications/version-management/bazaar/tools.nix) {
    inherit bazaar;
  };

  beast = callPackage ../applications/audio/beast {
    inherit (gnome) libgnomecanvas libart_lgpl;
    guile = guile_1_8;
  };

  bibletime = callPackage ../applications/misc/bibletime { };

  bitcoin = callPackage ../applications/misc/bitcoin {};
  bitcoind = callPackage ../applications/misc/bitcoin { gui = false; };

  altcoins = recurseIntoAttrs (
    (callPackage ../applications/misc/bitcoin/altcoins.nix {}) //
    (callPackage ../applications/misc/bitcoin/dogecoin.nix {})
  );

  bitlbee = callPackage ../applications/networking/instant-messengers/bitlbee { };

  blender = callPackage  ../applications/misc/blender {
    python = python34;
  };

  bluefish = callPackage ../applications/editors/bluefish {
    gtk = gtk3;
  };

  bristol = callPackage ../applications/audio/bristol { };

  bspwm = callPackage ../applications/window-managers/bspwm { };

  bvi = callPackage ../applications/editors/bvi { };

  calf = callPackage ../applications/audio/calf {
      inherit (gnome) libglade;
  };

  calibre = callPackage ../applications/misc/calibre {
    inherit (pythonPackages) pyqt5 sip_4_16;
  };

  camlistore = callPackage ../applications/misc/camlistore { };

  carrier = builderDefsPackage (import ../applications/networking/instant-messengers/carrier/2.5.0.nix) {
    inherit fetchurl stdenv pkgconfig perl perlXMLParser libxml2 openssl nss
      gtkspell aspell gettext ncurses avahi dbus dbus_glib python
      libtool automake autoconf gstreamer;
    inherit gtk glib;
    inherit (gnome) startupnotification GConf ;
    inherit (xlibs) libXScrnSaver scrnsaverproto libX11 xproto kbproto;
  };
  funpidgin = carrier;

  cc1394 = callPackage ../applications/video/cc1394 { };

  cddiscid = callPackage ../applications/audio/cd-discid { };

  cdparanoia = cdparanoiaIII;

  cdparanoiaIII = callPackage ../applications/audio/cdparanoia { };

  cdrtools = callPackage ../applications/misc/cdrtools { };

  centerim = callPackage ../applications/networking/instant-messengers/centerim { };

  cgit = callPackage ../applications/version-management/git-and-tools/cgit { };

  cgminer = callPackage ../applications/misc/cgminer {
    amdappsdk = amdappsdk28;
  };

  chatzilla = callPackage ../applications/networking/irc/chatzilla { };

  chromium = callPackage ../applications/networking/browsers/chromium {
    channel = "stable";
    pulseSupport = config.pulseaudio or true;
    enablePepperFlash = config.chromium.enablePepperFlash or false;
    enableWideVine = config.chromium.enableWideVine or false;
    hiDPISupport = config.chromium.hiDPISupport or false;
  };

  chromiumBeta = lowPrio (chromium.override { channel = "beta"; });

  chromiumDev = lowPrio (chromium.override { channel = "dev"; });

  chuck = callPackage ../applications/audio/chuck { };

  cinelerra = callPackage ../applications/video/cinelerra { };

  clawsMail = callPackage ../applications/networking/mailreaders/claws-mail {
    enableNetworkManager = config.networking.networkmanager.enable or false;
  };

  clipit = callPackage ../applications/misc/clipit { };

  cmplayer = callPackage ../applications/video/cmplayer {
    pulseSupport = config.pulseaudio or false;
  };

  cmus = callPackage ../applications/audio/cmus { };

  compiz = callPackage ../applications/window-managers/compiz {
    inherit (gnome) GConf ORBit2 metacity;
  };

  coriander = callPackage ../applications/video/coriander {
    inherit (gnome) libgnomeui GConf;
  };

  csound = callPackage ../applications/audio/csound { };

  cinepaint = callPackage ../applications/graphics/cinepaint {
    fltk = fltk13;
    libpng = libpng12;
  };

  codeblocks = callPackage ../applications/editors/codeblocks { };
  codeblocksFull = callPackage ../applications/editors/codeblocks { contribPlugins = true; };

  codeville = builderDefsPackage (import ../applications/version-management/codeville/0.8.0.nix) {
    inherit makeWrapper;
    python = pythonFull;
  };

  comical = callPackage ../applications/graphics/comical { };

  conkeror = callPackage ../applications/networking/browsers/conkeror { };

  conkerorWrapper = wrapFirefox {
    browser = conkeror;
    browserName = "conkeror";
    desktopName = "Conkeror";
  };

  cuneiform = builderDefsPackage (import ../tools/graphics/cuneiform) {
    inherit cmake patchelf;
    imagemagick = imagemagick;
  };

  cvs = callPackage ../applications/version-management/cvs { };

  cvsps = callPackage ../applications/version-management/cvsps { };

  cvs2svn = callPackage ../applications/version-management/cvs2svn { };

  d4x = callPackage ../applications/misc/d4x { };

  darcs = with haskellPackages_ghc783; callPackage ../applications/version-management/darcs {
    cabal = cabal.override {
      extension = self : super : {
        enableSharedExecutables = false;
        isLibrary = false;
        configureFlags = "-f-library " + super.configureFlags or "";
      };
    };
  };

  darktable = callPackage ../applications/graphics/darktable {
    inherit (gnome) GConf libglade;
  };

  dd-agent = callPackage ../tools/networking/dd-agent { inherit (pythonPackages) tornado; };

  deadbeef = callPackage ../applications/audio/deadbeef {
    pulseSupport = config.pulseaudio or true;
  };

  dia = callPackage ../applications/graphics/dia {
    inherit (pkgs.gnome) libart_lgpl libgnomeui;
  };

  diffuse = callPackage ../applications/version-management/diffuse { };

  distrho = callPackage ../applications/audio/distrho {};

  djvulibre = callPackage ../applications/misc/djvulibre { };

  djvu2pdf = callPackage ../tools/typesetting/djvu2pdf { };

  djview = callPackage ../applications/graphics/djview { };
  djview4 = pkgs.djview;

  dmenu = callPackage ../applications/misc/dmenu {
    enableXft = config.dmenu.enableXft or false;
  };

  dmenu2 = callPackage ../applications/misc/dmenu2 { };

  dmtx = dmtx-utils;

  dmtx-utils = callPackage (import ../tools/graphics/dmtx-utils) {
  };

  docker = callPackage ../applications/virtualization/docker { };

  doodle = callPackage ../applications/search/doodle { };

  dunst = callPackage ../applications/misc/dunst { };

  dvb_apps  = callPackage ../applications/video/dvb-apps { };

  dvdauthor = callPackage ../applications/video/dvdauthor { };

  dwb = callPackage ../applications/networking/browsers/dwb { dconf = gnome3.dconf; };

  dwbWrapper = wrapFirefox
    { browser = dwb; browserName = "dwb"; desktopName = "dwb";
    };

  dwm = callPackage ../applications/window-managers/dwm {
    patches = config.dwm.patches or [];
  };

  dzen2 = callPackage ../applications/window-managers/dzen2 { };

  eaglemode = callPackage ../applications/misc/eaglemode { };

  eclipses = recurseIntoAttrs (callPackage ../applications/editors/eclipse { });

  ed = callPackage ../applications/editors/ed { };

  ekho = callPackage ../applications/audio/ekho { };

  electrum = callPackage ../applications/misc/electrum { };

  elinks = callPackage ../applications/networking/browsers/elinks { };

  elvis = callPackage ../applications/editors/elvis { };

  emacs = emacs24;

  emacs24 = callPackage ../applications/editors/emacs-24 {
    # use override to enable additional features
    libXaw = xlibs.libXaw;
    Xaw3d = null;
    gconf = null;
    alsaLib = null;
    imagemagick = null;
  };

  emacs24-nox = lowPrio (appendToName "nox" (emacs24.override {
    withX = false;
  }));

  emacs24Macport_24_3 = lowPrio (callPackage ../applications/editors/emacs-24/macport-24.3.nix {
    stdenv = pkgs.clangStdenv;
  });
  emacs24Macport_24_4 = lowPrio (callPackage ../applications/editors/emacs-24/macport-24.4.nix {
    stdenv = pkgs.clangStdenv;
  });
  emacs24Macport = self.emacs24Macport_24_4;

  emacsPackages = emacs: self: let callPackage = newScope self; in rec {
    inherit emacs;

    autoComplete = callPackage ../applications/editors/emacs-modes/auto-complete { };

    bbdb = callPackage ../applications/editors/emacs-modes/bbdb { };

    bbdb3 = callPackage ../applications/editors/emacs-modes/bbdb/3.nix {};

    cedet = callPackage ../applications/editors/emacs-modes/cedet { };

    calfw = callPackage ../applications/editors/emacs-modes/calfw { };

    coffee = callPackage ../applications/editors/emacs-modes/coffee { };

    colorTheme = callPackage ../applications/editors/emacs-modes/color-theme { };

    colorThemeSolarized = callPackage ../applications/editors/emacs-modes/color-theme-solarized { };

    cryptol = callPackage ../applications/editors/emacs-modes/cryptol { };

    cua = callPackage ../applications/editors/emacs-modes/cua { };

    darcsum = callPackage ../applications/editors/emacs-modes/darcsum { };

    dash = callPackage ../applications/editors/emacs-modes/dash { };

    # ecb = callPackage ../applications/editors/emacs-modes/ecb { };

    emacsClangCompleteAsync = callPackage ../applications/editors/emacs-modes/emacs-clang-complete-async { };

    emacsSessionManagement = callPackage ../applications/editors/emacs-modes/session-management-for-emacs { };

    emacsw3m = callPackage ../applications/editors/emacs-modes/emacs-w3m { };

    emms = callPackage ../applications/editors/emacs-modes/emms { };

    ensime = callPackage ../applications/editors/emacs-modes/ensime { };

    ess = callPackage ../applications/editors/emacs-modes/ess { };

    flymakeCursor = callPackage ../applications/editors/emacs-modes/flymake-cursor { };

    gh = callPackage ../applications/editors/emacs-modes/gh { };

    graphvizDot = callPackage ../applications/editors/emacs-modes/graphviz-dot { };

    gist = callPackage ../applications/editors/emacs-modes/gist { };

    gitModes = callPackage ../applications/editors/emacs-modes/git-modes { };

    haskellMode = callPackage ../applications/editors/emacs-modes/haskell { };

    hsc3Mode = callPackage ../applications/editors/emacs-modes/hsc3 { };

    hol_light_mode = callPackage ../applications/editors/emacs-modes/hol_light { };

    htmlize = callPackage ../applications/editors/emacs-modes/htmlize { };

    icicles = callPackage ../applications/editors/emacs-modes/icicles { };

    idris = callPackage ../applications/editors/emacs-modes/idris { };

    jabber = callPackage ../applications/editors/emacs-modes/jabber { };

    jade = callPackage ../applications/editors/emacs-modes/jade { };

    jdee = callPackage ../applications/editors/emacs-modes/jdee { };

    js2 = callPackage ../applications/editors/emacs-modes/js2 { };

    logito = callPackage ../applications/editors/emacs-modes/logito { };

    loremIpsum = callPackage ../applications/editors/emacs-modes/lorem-ipsum { };

    magit = callPackage ../applications/editors/emacs-modes/magit { };

    maudeMode = callPackage ../applications/editors/emacs-modes/maude { };

    metaweblog = callPackage ../applications/editors/emacs-modes/metaweblog { };

    notmuch = lowPrio (pkgs.notmuch.override { inherit emacs; });

    ocamlMode = callPackage ../applications/editors/emacs-modes/ocaml { };

    offlineimap = callPackage ../applications/editors/emacs-modes/offlineimap {};

    # This is usually a newer version of Org-Mode than that found in GNU Emacs, so
    # we want it to have higher precedence.
    org = hiPrio (callPackage ../applications/editors/emacs-modes/org { });

    org2blog = callPackage ../applications/editors/emacs-modes/org2blog { };

    pcache = callPackage ../applications/editors/emacs-modes/pcache { };

    phpMode = callPackage ../applications/editors/emacs-modes/php { };

    prologMode = callPackage ../applications/editors/emacs-modes/prolog { };

    proofgeneral_4_2 = callPackage ../applications/editors/emacs-modes/proofgeneral/4.2.nix {
      texinfo = texinfo4 ;
      texLive = pkgs.texLiveAggregationFun {
        paths = [ pkgs.texLive pkgs.texLiveCMSuper ];
      };
    };
    proofgeneral_4_3_pre = callPackage ../applications/editors/emacs-modes/proofgeneral/4.3pre.nix {
      texinfo = texinfo4 ;
      texLive = pkgs.texLiveAggregationFun {
        paths = [ pkgs.texLive pkgs.texLiveCMSuper ];
      };
    };
    proofgeneral = self.proofgeneral_4_2;

    quack = callPackage ../applications/editors/emacs-modes/quack { };

    rainbowDelimiters = callPackage ../applications/editors/emacs-modes/rainbow-delimiters { };

    rectMark = callPackage ../applications/editors/emacs-modes/rect-mark { };

    remember = callPackage ../applications/editors/emacs-modes/remember { };

    rudel = callPackage ../applications/editors/emacs-modes/rudel { };

    s = callPackage ../applications/editors/emacs-modes/s { };

    sbtMode = callPackage ../applications/editors/emacs-modes/sbt-mode { };

    scalaMode1 = callPackage ../applications/editors/emacs-modes/scala-mode/v1.nix { };
    scalaMode2 = callPackage ../applications/editors/emacs-modes/scala-mode/v2.nix { };

    stratego = callPackage ../applications/editors/emacs-modes/stratego { };

    structuredHaskellMode = callPackage ../applications/editors/emacs-modes/structured-haskell-mode {
      inherit (haskellPackages) cabal ;
      haskellSrcExts = haskellPackages.haskellSrcExts_1_15_0_1;
    };

    sunriseCommander = callPackage ../applications/editors/emacs-modes/sunrise-commander { };

    tuaregMode = callPackage ../applications/editors/emacs-modes/tuareg { };

    writeGood = callPackage ../applications/editors/emacs-modes/writegood { };

    xmlRpc = callPackage ../applications/editors/emacs-modes/xml-rpc { };

    cask = callPackage ../applications/editors/emacs-modes/cask { };
  };

  emacs24Packages = recurseIntoAttrs (emacsPackages emacs24 pkgs.emacs24Packages);

  inherit (gnome3) empathy;

  epdfview = callPackage ../applications/misc/epdfview { };

  inherit (gnome3) epiphany;

  espeak = callPackage ../applications/audio/espeak { };

  espeakedit = callPackage ../applications/audio/espeak/edit.nix { };

  esniper = callPackage ../applications/networking/esniper { };

  etherape = callPackage ../applications/networking/sniffers/etherape {
    inherit (gnome) gnomedocutils libgnome libglade libgnomeui scrollkeeper;
  };

  evilvte = callPackage ../applications/misc/evilvte {
    configH = config.evilvte.config or "";
  };

  evopedia = callPackage ../applications/misc/evopedia { };

  keepassx = callPackage ../applications/misc/keepassx { };
  keepassx2 = callPackage ../applications/misc/keepassx/2.0.nix { };

  inherit (gnome3) evince;
  evolution_data_server = gnome3.evolution_data_server;

  keepass = callPackage ../applications/misc/keepass { };

  exrdisplay = callPackage ../applications/graphics/exrdisplay {
    fltk = fltk20;
  };

  fbpanel = callPackage ../applications/window-managers/fbpanel { };

  fbreader = callPackage ../applications/misc/fbreader { };

  fetchmail = import ../applications/misc/fetchmail {
    inherit stdenv fetchurl openssl;
  };

  fldigi = callPackage ../applications/audio/fldigi { };

  fluidsynth = callPackage ../applications/audio/fluidsynth { };

  focuswriter = callPackage ../applications/editors/focuswriter { };

  fossil = callPackage ../applications/version-management/fossil { };

  freewheeling = callPackage ../applications/audio/freewheeling { };

  fribid = callPackage ../applications/networking/browsers/mozilla-plugins/fribid { };

  fritzing = callPackage ../applications/science/electronics/fritzing { };

  fvwm = callPackage ../applications/window-managers/fvwm { };

  geany = callPackage ../applications/editors/geany { };

  gksu = callPackage ../applications/misc/gksu { };

  gnuradio = callPackage ../applications/misc/gnuradio {
    inherit (pythonPackages) lxml numpy scipy matplotlib pyopengl;
    fftw = fftwFloat;
  };

  gnuradio-osmosdr = callPackage ../applications/misc/gnuradio-osmosdr { };

  goldendict = callPackage ../applications/misc/goldendict { };

  google-musicmanager = callPackage ../applications/audio/google-musicmanager { };

  gpicview = callPackage ../applications/graphics/gpicview { };

  gqrx = callPackage ../applications/misc/gqrx { };

  grass = import ../applications/misc/grass {
    inherit (xlibs) libXmu libXext libXp libX11 libXt libSM libICE libXpm
      libXaw libXrender;
    inherit config composableDerivation stdenv fetchurl
      lib flex bison cairo fontconfig
      gdal zlib ncurses gdbm proj pkgconfig swig
      blas liblapack libjpeg libpng mysql unixODBC mesa postgresql python
      readline sqlite tcl tk libtiff freetype makeWrapper wxGTK;
    fftw = fftwSinglePrec;
    ffmpeg = ffmpeg_0_10;
    motif = lesstif;
    opendwg = libdwg;
    wxPython = wxPython28;
  };

  grip = callPackage ../applications/misc/grip {
    inherit (gnome) libgnome libgnomeui vte;
  };

  gtimelog = pythonPackages.gtimelog;

  inherit (gnome3) gucharmap;

  guitarix = callPackage ../applications/audio/guitarix {
    fftw = fftwSinglePrec;
  };

  photivo = callPackage ../applications/graphics/photivo { };

  wavesurfer = callPackage ../applications/misc/audio/wavesurfer { };

  wireshark-cli = callPackage ../applications/networking/sniffers/wireshark {
    withQt = false;
    withGtk = false;
  };
  wireshark-gtk = wireshark-cli.override { withGtk = true; };
  wireshark-qt = wireshark-cli.override { withQt = true; };
  wireshark = wireshark-gtk;

  wvdial = callPackage ../os-specific/linux/wvdial { };

  fbida = callPackage ../applications/graphics/fbida { };

  fdupes = callPackage ../tools/misc/fdupes { };

  feh = callPackage ../applications/graphics/feh { };

  filezilla = callPackage ../applications/networking/ftp/filezilla { };

  firefox = callPackage ../applications/networking/browsers/firefox {
    inherit (gnome) libIDL;
    inherit (pythonPackages) pysqlite;
  };

  firefoxWrapper = wrapFirefox { browser = pkgs.firefox; };

  firefox-bin = callPackage ../applications/networking/browsers/firefox-bin {
    gconf = pkgs.gnome.GConf;
    inherit (pkgs.gnome) libgnome libgnomeui;
    inherit (pkgs.xlibs) libX11 libXScrnSaver libXcomposite libXdamage libXext
      libXfixes libXinerama libXrender libXt;
  };

  flac = callPackage ../applications/audio/flac { };

  flashplayer = callPackage ../applications/networking/browsers/mozilla-plugins/flashplayer-11 {
    debug = config.flashplayer.debug or false;
  };

  fluxbox = callPackage ../applications/window-managers/fluxbox { };

  fme = callPackage ../applications/misc/fme {
    inherit (gnome) libglademm;
    inherit pkgconfig autoconf automake gettext;
  };

  freecad = callPackage ../applications/graphics/freecad {
    opencascade = opencascade_6_5;
    inherit (pythonPackages) matplotlib pycollada;
  };

  freemind = callPackage ../applications/misc/freemind {
    jdk = jdk;
    jre = jdk;
  };

  freenet = callPackage ../applications/networking/p2p/freenet { };

  freepv = callPackage ../applications/graphics/freepv { };

  xfontsel = callPackage ../applications/misc/xfontsel { };
  xlsfonts = callPackage ../applications/misc/xlsfonts { };

  freerdp = callPackage ../applications/networking/remote/freerdp {
    ffmpeg = ffmpeg_1;
  };

  freerdpUnstable = callPackage ../applications/networking/remote/freerdp/unstable.nix { };

  freicoin = callPackage ../applications/misc/freicoin { };

  fspot = callPackage ../applications/graphics/f-spot {
    inherit (gnome) libgnome libgnomeui;
    gtksharp = gtksharp1;
  };

  fuze = callPackage ../applications/networking/instant-messengers/fuze {};

  gcolor2 = callPackage ../applications/graphics/gcolor2 { };

  get_iplayer = callPackage ../applications/misc/get_iplayer {};

  gimp_2_8 = callPackage ../applications/graphics/gimp/2.8.nix {
    inherit (gnome) libart_lgpl;
    webkit = null;
    lcms = lcms2;
    wrapPython = pythonPackages.wrapPython;
  };

  gimp = gimp_2_8;

  gimpPlugins = recurseIntoAttrs (import ../applications/graphics/gimp/plugins {
    inherit pkgs gimp;
  });

  gitAndTools = recurseIntoAttrs (import ../applications/version-management/git-and-tools {
    inherit pkgs;
  });
  git = gitAndTools.git;
  gitFull = gitAndTools.gitFull;
  gitMinimal = git.override {
    withManual = false;
    pythonSupport = false;
  };
  gitSVN = gitAndTools.gitSVN;

  gitRepo = callPackage ../applications/version-management/git-repo {
    python = python27;
  };

  gitolite = callPackage ../applications/version-management/gitolite { };

  inherit (gnome3) gitg;

  giv = callPackage ../applications/graphics/giv {
    pcre = pcre.override { unicodeSupport = true; };
  };

  gmrun = callPackage ../applications/misc/gmrun {};

  gnucash = callPackage ../applications/office/gnucash {
    inherit (gnome2) libgnomeui libgtkhtml gtkhtml libbonoboui libgnomeprint libglade libart_lgpl;
    gconf = gnome2.GConf;
    guile = guile_1_8;
    slibGuile = slibGuile.override { scheme = guile_1_8; };
    goffice = goffice_0_8;
  };

  goffice_0_8 = callPackage ../desktops/gnome-3/3.12/misc/goffice/0.8.nix {
    inherit (gnome2) libglade libgnomeui;
    gconf = gnome2.GConf;
    libart = gnome2.libart_lgpl;
  }; # latest version: gnome3.goffice

  idea = recurseIntoAttrs (callPackage ../applications/editors/idea { });

  libquvi = callPackage ../applications/video/quvi/library.nix { };

  linssid = callPackage ../applications/networking/linssid { };

  mi2ly = callPackage ../applications/audio/mi2ly {};

  praat = callPackage ../applications/audio/praat { };

  quvi = callPackage ../applications/video/quvi/tool.nix {
    lua5_sockets = lua5_1_sockets;
    lua5 = lua5_1;
  };

  quvi_scripts = callPackage ../applications/video/quvi/scripts.nix { };

  qjackctl = callPackage ../applications/audio/qjackctl { };

  gkrellm = callPackage ../applications/misc/gkrellm { };

  gmu = callPackage ../applications/audio/gmu { };

  gnash = callPackage ../applications/video/gnash {
    inherit (gnome) gtkglext;
  };

  gnome_mplayer = callPackage ../applications/video/gnome-mplayer {
    inherit (gnome) GConf;
  };

  gnumeric = callPackage ../applications/office/gnumeric {
    inherit (gnome3) goffice gnome_icon_theme;
  };

  gnunet = callPackage ../applications/networking/p2p/gnunet {
    libgcrypt = libgcrypt_1_6;
  };

  gnunet_svn = lowPrio (callPackage ../applications/networking/p2p/gnunet/svn.nix {
    libgcrypt = libgcrypt_1_6;
  });

  gocr = callPackage ../applications/graphics/gocr { };

  gobby5 = callPackage ../applications/editors/gobby {
    inherit (gnome) gtksourceview;
  };

  gphoto2 = callPackage ../applications/misc/gphoto2 { };

  gphoto2fs = builderDefsPackage ../applications/misc/gphoto2/gphotofs.nix {
    inherit libgphoto2 fuse pkgconfig glib libtool;
  };

  graphicsmagick = callPackage ../applications/graphics/graphicsmagick { };
  graphicsmagick_q16 = callPackage ../applications/graphics/graphicsmagick { quantumdepth = 16; };

  graphicsmagick137 = callPackage ../applications/graphics/graphicsmagick/1.3.7.nix {
    libpng = libpng12;
  };

  gtkpod = callPackage ../applications/audio/gtkpod {
    gnome = gnome3;
    inherit (gnome) libglade;
  };

  jbidwatcher = callPackage ../applications/misc/jbidwatcher {
    java = if stdenv.isLinux then jre else jdk;
  };

  qrdecode = builderDefsPackage (import ../tools/graphics/qrdecode) {
    libpng = libpng12;
    opencv = opencv_2_1;
  };

  qrencode = callPackage ../tools/graphics/qrencode { };

  gecko_mediaplayer = callPackage ../applications/networking/browsers/mozilla-plugins/gecko-mediaplayer {
    inherit (gnome) GConf;
    browser = firefox;
  };

  geeqie = callPackage ../applications/graphics/geeqie { };

  gigedit = callPackage ../applications/audio/gigedit { };

  gqview = callPackage ../applications/graphics/gqview { };

  gmpc = callPackage ../applications/audio/gmpc {
    inherit (xlibs) libSM libICE;
  };

  gmtk = callPackage ../applications/networking/browsers/mozilla-plugins/gmtk {
    inherit (gnome) GConf;
  };

  googleearth = callPackage_i686 ../applications/misc/googleearth { };

  google_talk_plugin = callPackage ../applications/networking/browsers/mozilla-plugins/google-talk-plugin {
    libpng = libpng12;
  };

  gosmore = callPackage ../applications/misc/gosmore { };

  gpsbabel = callPackage ../applications/misc/gpsbabel { };

  gpscorrelate = callPackage ../applications/misc/gpscorrelate { };

  gpsd = callPackage ../servers/gpsd { };

  guitone = callPackage ../applications/version-management/guitone {
    graphviz = graphviz_2_32;
  };

  gv = callPackage ../applications/misc/gv { };

  guvcview = callPackage ../os-specific/linux/guvcview { };

  hello = callPackage ../applications/misc/hello/ex-2 { };

  herbstluftwm = callPackage ../applications/window-managers/herbstluftwm { };

  hexchat = callPackage ../applications/networking/irc/hexchat { };

  hexedit = callPackage ../applications/editors/hexedit { };

  hipchat = callPackage ../applications/networking/instant-messengers/hipchat { };

  homebank = callPackage ../applications/office/homebank { };

  htmldoc = callPackage ../applications/misc/htmldoc {
    fltk = fltk13;
  };

  hugin = callPackage ../applications/graphics/hugin {
    boost = boost155;
  };

  hydrogen = callPackage ../applications/audio/hydrogen { };

  i3 = callPackage ../applications/window-managers/i3 { };

  i3lock = callPackage ../applications/window-managers/i3/lock.nix {
    inherit (xorg) libxkbfile;
    cairo = cairo.override { xcbSupport = true; };
  };

  i3minator = callPackage ../tools/misc/i3minator { };

  i3status = callPackage ../applications/window-managers/i3/status.nix { };

  i810switch = callPackage ../os-specific/linux/i810switch { };

  icewm = callPackage ../applications/window-managers/icewm { };

  id3v2 = callPackage ../applications/audio/id3v2 { };

  ifenslave = callPackage ../os-specific/linux/ifenslave { };

  ii = callPackage ../applications/networking/irc/ii { };

  ike = callPackage ../applications/networking/ike { };

  ikiwiki = callPackage ../applications/misc/ikiwiki {
    inherit (perlPackages) TextMarkdown URI HTMLParser HTMLScrubber
      HTMLTemplate TimeDate CGISession DBFile CGIFormBuilder LocaleGettext
      RpcXML XMLSimple PerlMagick YAML YAMLLibYAML HTMLTree Filechdir
      AuthenPassphrase NetOpenIDConsumer LWPxParanoidAgent CryptSSLeay;
  };

  imagemagick = callPackage ../applications/graphics/ImageMagick {
    tetex = null;
    librsvg = null;
  };

  imagemagickBig = lowPrio (callPackage ../applications/graphics/ImageMagick { });

  # Impressive, formerly known as "KeyJNote".
  impressive = callPackage ../applications/office/impressive {
    # XXX These are the PyOpenGL dependencies, which we need here.
    inherit (pythonPackages) pyopengl;
  };

  inferno = callPackage_i686 ../applications/inferno { };

  inkscape = callPackage ../applications/graphics/inkscape {
    inherit (pythonPackages) lxml;
    lcms = lcms2;
  };

  ion3 = callPackage ../applications/window-managers/ion-3 {
    lua = lua5;
  };

  ipe = callPackage ../applications/graphics/ipe { };

  iptraf = callPackage ../applications/networking/iptraf { };

  irssi = callPackage ../applications/networking/irc/irssi {
    # compile with gccApple on darwin to support the -no-cpp-precompile flag
    stdenv = if stdenv.isDarwin
      then stdenvAdapters.overrideGCC stdenv gccApple
      else stdenv;
  };

  irssi_fish = callPackage ../applications/networking/irc/irssi/fish { };

  irssi_otr = callPackage ../applications/networking/irc/irssi/otr { };

  bip = callPackage ../applications/networking/irc/bip { };

  jack_capture = callPackage ../applications/audio/jack-capture { };

  jack_oscrolloscope = callPackage ../applications/audio/jack-oscrolloscope { };

  jack_rack = callPackage ../applications/audio/jack-rack { };

  jackmeter = callPackage ../applications/audio/jackmeter { };

  jalv = callPackage ../applications/audio/jalv { };

  jedit = callPackage ../applications/editors/jedit { };

  jigdo = callPackage ../applications/misc/jigdo { };

  jitsi = callPackage ../applications/networking/instant-messengers/jitsi { };

  joe = callPackage ../applications/editors/joe { };

  jbrout = callPackage ../applications/graphics/jbrout {
    inherit (pythonPackages) lxml;
  };

  jwm = callPackage ../applications/window-managers/jwm { };

  k3d = callPackage ../applications/graphics/k3d {
    inherit (pkgs.gnome2) gtkglext;
    boost = boost155;
  };

  keepnote = callPackage ../applications/office/keepnote {
    pygtk = pyGtkGlade;
  };

  kermit = callPackage ../tools/misc/kermit { };

  keymon = callPackage ../applications/video/key-mon { };

  kid3 = callPackage ../applications/audio/kid3 {
    qt = qt4;
  };

  kino = callPackage ../applications/video/kino {
    inherit (gnome) libglade;
  };

  koji = callPackage ../tools/package-management/koji { };

  kubernetes = callPackage ../applications/networking/cluster/kubernetes { };

  lame = callPackage ../applications/audio/lame { };

  larswm = callPackage ../applications/window-managers/larswm { };

  lash = callPackage ../applications/audio/lash { };

  ladspaH = callPackage ../applications/audio/ladspa-plugins/ladspah.nix { };

  ladspaPlugins = callPackage ../applications/audio/ladspa-plugins {
    fftw = fftwSinglePrec;
  };

  caps = callPackage ../applications/audio/caps { };

  lastwatch = callPackage ../applications/audio/lastwatch { };

  lastfmsubmitd = callPackage ../applications/audio/lastfmsubmitd { };

  lbdb = callPackage ../tools/misc/lbdb { };

  lbzip2 = callPackage ../tools/compression/lbzip2 { };

  lci = callPackage ../applications/science/logic/lci {};

  ldcpp = callPackage ../applications/networking/p2p/ldcpp {
    inherit (gnome) libglade;
  };

  libowfat = callPackage ../development/libraries/libowfat { };

  librecad = callPackage ../applications/misc/librecad { };

  librecad2 = callPackage ../applications/misc/librecad/2.0.nix { };

  libreoffice = callPackage ../applications/office/libreoffice {
    inherit (perlPackages) ArchiveZip CompressZlib;
    inherit (gnome) GConf ORBit2 gnome_vfs;
    zip = zip.override { enableNLS = false; };
    jdk = openjdk;
    boost = boost155;
    fontsConf = makeFontsConf {
      fontDirectories = [
        freefont_ttf xorg.fontmiscmisc xorg.fontbhttf
      ];
    };
    clucene_core = clucene_core_2;
    lcms = lcms2;
    harfbuzz = harfbuzz.override {
      withIcu = true; withGraphite2 = true;
    };
  };

  liferea = callPackage ../applications/networking/newsreaders/liferea {
    webkitgtk = webkitgtk24x;
  };

  lingot = callPackage ../applications/audio/lingot {
    inherit (gnome) libglade;
  };

  links = callPackage ../applications/networking/browsers/links { };

  ledger2 = callPackage ../applications/office/ledger/2.6.3.nix { };
  ledger3 = callPackage ../applications/office/ledger { };
  ledger = ledger3;

  lighttable = callPackage ../applications/editors/lighttable {};

  links2 = callPackage ../applications/networking/browsers/links2 { };

  linphone = callPackage ../applications/networking/instant-messengers/linphone rec {
    inherit (gnome) libglade;
    libexosip = libexosip_3;
    libosip = libosip_3;
  };

  linuxsampler = callPackage ../applications/audio/linuxsampler {
    bison = bison2;
  };

  llpp = callPackage ../applications/misc/llpp { inherit (ocamlPackages) lablgl; };

  lmms = callPackage ../applications/audio/lmms { };

  lrzsz = callPackage ../tools/misc/lrzsz { };

  luminanceHDR = callPackage ../applications/graphics/luminance-hdr { };

  lxdvdrip = callPackage ../applications/video/lxdvdrip { };

  handbrake = callPackage ../applications/video/handbrake {
    webkitgtk = webkitgtk24x;
  };

  lilyterm = callPackage ../applications/misc/lilyterm {
    inherit (gnome) vte;
    gtk = gtk2;
  };

  lynx = callPackage ../applications/networking/browsers/lynx { };

  lyx = callPackage ../applications/misc/lyx { };

  makeself = callPackage ../applications/misc/makeself { };

  matchbox = callPackage ../applications/window-managers/matchbox { };

  mcpp = callPackage ../development/compilers/mcpp { };

  mda_lv2 = callPackage ../applications/audio/mda-lv2 { };

  meld = callPackage ../applications/version-management/meld {
    inherit (gnome) scrollkeeper;
    pygtk = pyGtkGlade;
  };

  mcomix = callPackage ../applications/graphics/mcomix { };

  mercurial = callPackage ../applications/version-management/mercurial {
    inherit (pythonPackages) curses docutils;
    guiSupport = false; # use mercurialFull to get hgk GUI
  };

  mercurialFull = appendToName "full" (pkgs.mercurial.override { guiSupport = true; });

  merkaartor = callPackage ../applications/misc/merkaartor { };

  meshlab = callPackage ../applications/graphics/meshlab { };

  mhwaveedit = callPackage ../applications/audio/mhwaveedit {};

  mid2key = callPackage ../applications/audio/mid2key { };

  midori = callPackage ../applications/networking/browsers/midori {
    webkitgtk = webkitgtk24x;
  };

  midoriWrapper = wrapFirefox
    { browser = midori; browserName = "midori"; desktopName = "Midori";
      icon = "${midori}/share/icons/hicolor/22x22/apps/midori.png";
    };

  mikmod = callPackage ../applications/audio/mikmod { };

  minicom = callPackage ../tools/misc/minicom { };

  minimodem = callPackage ../applications/audio/minimodem { };

  minidjvu = callPackage ../applications/graphics/minidjvu { };

  mirage = callPackage ../applications/graphics/mirage {};

  mixxx = callPackage ../applications/audio/mixxx {
    inherit (vamp) vampSDK;
  };

  mmex = callPackage ../applications/office/mmex { };

  moc = callPackage ../applications/audio/moc { };

  monero = callPackage ../applications/misc/monero { };

  monkeysAudio = callPackage ../applications/audio/monkeys-audio { };

  monodevelop = callPackage ../applications/editors/monodevelop {
    inherit (gnome) gnome_vfs libbonobo libglade libgnome GConf;
    mozilla = firefox;
    gtksharp = gtksharp2;
  };

  monodoc = callPackage ../applications/editors/monodoc {
    gtksharp = gtksharp1;
  };

  monotone = callPackage ../applications/version-management/monotone {
    lua = lua5;
  };

  monotoneViz = builderDefsPackage (import ../applications/version-management/monotone-viz/mtn-head.nix) {
    inherit graphviz pkgconfig autoconf automake libtool glib gtk;
    inherit (ocamlPackages_4_01_0) lablgtk ocaml;
    inherit (gnome) libgnomecanvas;
  };

  mopidy = callPackage ../applications/audio/mopidy { };

  mopidy-spotify = callPackage ../applications/audio/mopidy-spotify { };

  mopidy-moped = callPackage ../applications/audio/mopidy-moped { };

  mozilla = callPackage ../applications/networking/browsers/mozilla {
    inherit (gnome) libIDL;
  };

  mozplugger = builderDefsPackage (import ../applications/networking/browsers/mozilla-plugins/mozplugger) {
    inherit firefox;
    inherit (xlibs) libX11 xproto;
  };

  easytag = callPackage ../applications/audio/easytag {
    inherit (gnome3) gnome_icon_theme;
  };

  mp3info = callPackage ../applications/audio/mp3info { };

  mp3splt = callPackage ../applications/audio/mp3splt { };

  mpc123 = callPackage ../applications/audio/mpc123 { };

  mpg123 = callPackage ../applications/audio/mpg123 { };

  mpg321 = callPackage ../applications/audio/mpg321 { };

  mpc_cli = callPackage ../applications/audio/mpc { };

  ncmpc = callPackage ../applications/audio/ncmpc { };

  ncmpcpp = callPackage ../applications/audio/ncmpcpp { };

  normalize = callPackage ../applications/audio/normalize { };

  mplayer = callPackage ../applications/video/mplayer {
    pulseSupport = config.pulseaudio or false;
    vdpauSupport = config.mplayer.vdpauSupport or false;
  };

  mplayer2 = callPackage ../applications/video/mplayer2 {
    ffmpeg = libav_9; # see https://trac.macports.org/ticket/44386
  };

  MPlayerPlugin = browser:
    import ../applications/networking/browsers/mozilla-plugins/mplayerplug-in {
      inherit browser;
      inherit fetchurl stdenv pkgconfig gettext;
      inherit (xlibs) libXpm;
      # !!! should depend on MPlayer
    };

  mpv = callPackage ../applications/video/mpv {
    lua = lua5_1;
    lua5_sockets = lua5_1_sockets;
    bs2bSupport = config.mpv.bs2bSupport or true;
    quviSupport = config.mpv.quviSupport or false;
    cacaSupport = config.mpv.cacaSupport or true;
    vaapiSupport = config.mpv.vaapiSupport or false;
  };

  mrxvt = callPackage ../applications/misc/mrxvt { };

  mudlet = callPackage ../games/mudlet {
    inherit (lua51Packages) luafilesystem lrexlib luazip luasqlite3;
  };

  multisync = callPackage ../applications/misc/multisync {
    inherit (gnome) ORBit2 libbonobo libgnomeui GConf;
  };

  mumble = callPackage ../applications/networking/mumble {
    avahi = avahi.override {
      withLibdnssdCompat = true;
    };
    jackSupport = config.mumble.jackSupport or false;
    speechdSupport = config.mumble.speechdSupport or false;
  };

  murmur = callPackage ../applications/networking/mumble/murmur.nix {
    avahi = avahi.override {
      withLibdnssdCompat = true;
    };
    iceSupport = config.murmur.iceSupport or true;
  };

  musescore = callPackage ../applications/audio/musescore { };

  mutt = callPackage ../applications/networking/mailreaders/mutt { };
  mutt-with-sidebar = callPackage ../applications/networking/mailreaders/mutt {
    withSidebar = true;
  };

  namecoin = callPackage ../applications/misc/namecoin { };
  namecoinqt = callPackage ../applications/misc/namecoin/qt.nix { };

  pcmanfm = callPackage ../applications/misc/pcmanfm { };

  ruby_gpgme = callPackage ../development/libraries/ruby_gpgme {
    ruby = ruby_1_9_3;
    hoe = rubyLibs.hoe;
  };

  ruby_ncursesw_sup = callPackage ../development/libraries/ruby_ncursesw_sup { };

  shotcut = callPackage ../applications/video/shotcut { mlt = mlt-qt5; };

  smplayer = callPackage ../applications/video/smplayer { };

  smtube = callPackage ../applications/video/smtube {};

  sup = with rubyLibs; callPackage ../applications/networking/mailreaders/sup {
    ruby = ruby_1_9_3.override {
      cursesSupport = true;
    };

    inherit gettext highline iconv locale lockfile
      text trollop xapian_ruby which;

    rmail_sup = ""; # missing
    unicode = "";

    # See https://github.com/NixOS/nixpkgs/issues/1804 and
    # https://github.com/NixOS/nixpkgs/issues/2146
    bundler = pkgs.lib.overrideDerivation pkgs.rubyLibs.bundler (
      oldAttrs: {
        dontPatchShebangs = 1;
      }
    );
    chronic      = chronic;
    gpgme        = ruby_gpgme;
    mime_types   = mime_types;
    ncursesw_sup = ruby_ncursesw_sup;
    rake         = rake;
  };

  synfigstudio = callPackage ../applications/graphics/synfigstudio {
    fontsConf = makeFontsConf { fontDirectories = [ freefont_ttf ]; };
  };

  sxhkd = callPackage ../applications/window-managers/sxhkd { };

  msmtp = callPackage ../applications/networking/msmtp { };

  imapfilter = callPackage ../applications/networking/mailreaders/imapfilter.nix {
    lua = lua5;
 };

  mupdf = callPackage ../applications/misc/mupdf { };

  mypaint = callPackage ../applications/graphics/mypaint { };

  mythtv = callPackage ../applications/video/mythtv { };

  tvtime = callPackage ../applications/video/tvtime {
    kernel = linux;
  };

  nano = callPackage ../applications/editors/nano { };

  nanoblogger = callPackage ../applications/misc/nanoblogger { };

  navipowm = callPackage ../applications/misc/navipowm { };

  navit = callPackage ../applications/misc/navit { };

  netbeans = callPackage ../applications/editors/netbeans { };

  ncdu = callPackage ../tools/misc/ncdu { };

  ncdc = callPackage ../applications/networking/p2p/ncdc { };

  nedit = callPackage ../applications/editors/nedit {
    motif = lesstif;
  };

  netsurfBrowser = netsurf.browser;
  netsurf = recurseIntoAttrs (import ../applications/networking/browsers/netsurf { inherit pkgs; });

  notmuch = callPackage ../applications/networking/mailreaders/notmuch {
    # No need to build Emacs - notmuch.el works just fine without
    # byte-compilation. Use emacs24Packages.notmuch if you want to
    # byte-compiled files
    emacs = null;
    sphinx = pythonPackages.sphinx;
  };

  nova = callPackage ../applications/virtualization/nova { };

  novaclient = callPackage ../applications/virtualization/nova/client.nix { };

  nspluginwrapper = callPackage ../applications/networking/browsers/mozilla-plugins/nspluginwrapper {};

  nvi = callPackage ../applications/editors/nvi { };

  nvpy = callPackage ../applications/editors/nvpy { };

  obconf = callPackage ../tools/X11/obconf {
    inherit (gnome) libglade;
  };

  ocrad = callPackage ../applications/graphics/ocrad { };

  offrss = callPackage ../applications/networking/offrss { };

  ogmtools = callPackage ../applications/video/ogmtools { };

  omxplayer = callPackage ../applications/video/omxplayer { };

  oneteam = callPackage ../applications/networking/instant-messengers/oneteam {};

  openbox = callPackage ../applications/window-managers/openbox { };

  openbox-menu = callPackage ../applications/misc/openbox-menu { };

  openimageio = callPackage ../applications/graphics/openimageio { };

  openjump = callPackage ../applications/misc/openjump { };

  openscad = callPackage ../applications/graphics/openscad {};

  opera = callPackage ../applications/networking/browsers/opera {
    inherit (pkgs.kde4) kdelibs;
  };

  opusfile = callPackage ../applications/audio/opusfile { };

  opusTools = callPackage ../applications/audio/opus-tools { };

  pamixer = callPackage ../applications/audio/pamixer { };

  pan = callPackage ../applications/networking/newsreaders/pan {
    spellChecking = false;
  };

  panotools = callPackage ../applications/graphics/panotools { };

  paprefs = callPackage ../applications/audio/paprefs {
    inherit (gnome) libglademm gconfmm;
  };

  pavucontrol = callPackage ../applications/audio/pavucontrol { };

  paraview = callPackage ../applications/graphics/paraview { };

  pencil = callPackage ../applications/graphics/pencil { };

  petrifoo = callPackage ../applications/audio/petrifoo {
    inherit (gnome) libgnomecanvas;
  };

  pdftk = callPackage ../tools/typesetting/pdftk { };
  pdfgrep  = callPackage ../tools/typesetting/pdfgrep { };

  pianobar = callPackage ../applications/audio/pianobar { };

  pianobooster = callPackage ../applications/audio/pianobooster { };

  picard = callPackage ../applications/audio/picard {
    python-libdiscid = pythonPackages.discid;
    mutagen = pythonPackages.mutagen;
  };

  picocom = callPackage ../tools/misc/picocom { };

  pidgin = callPackage ../applications/networking/instant-messengers/pidgin {
    openssl = if config.pidgin.openssl or true then openssl else null;
    gnutls = if config.pidgin.gnutls or false then gnutls else null;
    libgcrypt = if config.pidgin.gnutls or false then libgcrypt else null;
    startupnotification = libstartup_notification;
    inherit (xlibs) libXext libICE libSM;
  };

  pidgin-with-plugins = callPackage ../applications/networking/instant-messengers/pidgin/wrapper.nix {
    plugins = [];
  };

  pidginlatex = callPackage ../applications/networking/instant-messengers/pidgin-plugins/pidgin-latex { };

  pidginlatexSF = pidginlatex;

  pidginmsnpecan = callPackage ../applications/networking/instant-messengers/pidgin-plugins/msn-pecan { };

  pidginotr = callPackage ../applications/networking/instant-messengers/pidgin-plugins/otr { };

  pidginsipe = callPackage ../applications/networking/instant-messengers/pidgin-plugins/sipe { };

  toxprpl = callPackage ../applications/networking/instant-messengers/pidgin-plugins/tox-prpl { };

  pinfo = callPackage ../applications/misc/pinfo { };

  pinpoint = callPackage ../applications/office/pinpoint {};

  pinta = callPackage ../applications/graphics/pinta {
    gtksharp = gtksharp2;
  };

  pommed = callPackage ../os-specific/linux/pommed {
    inherit (xorg) libXpm;
  };

  pond = callPackage ../applications/networking/pond { };

  potrace = callPackage ../applications/graphics/potrace {};

  posterazor = callPackage ../applications/misc/posterazor { };

  pqiv = callPackage ../applications/graphics/pqiv { };

  qiv = callPackage ../applications/graphics/qiv { };

  processing = callPackage ../applications/graphics/processing { inherit (xorg) libXxf86vm; };

  # perhaps there are better apps for this task? It's how I had configured my preivous system.
  # And I don't want to rewrite all rules
  procmail = callPackage ../applications/misc/procmail { };

  pstree = callPackage ../applications/misc/pstree { };

  pulseview = callPackage ../applications/science/electronics/pulseview { };

  puredata = callPackage ../applications/audio/puredata { };

  pythonmagick = callPackage ../applications/graphics/PythonMagick { };

  qbittorrent = callPackage ../applications/networking/p2p/qbittorrent {
    libtorrentRasterbar = libtorrentRasterbar_0_16;
  };

  eiskaltdcpp = callPackage ../applications/networking/p2p/eiskaltdcpp { lua5 = lua5_1; };

  qemu = callPackage ../applications/virtualization/qemu { };

  qmmp = callPackage ../applications/audio/qmmp { };

  qsampler = callPackage ../applications/audio/qsampler { };

  qsynth = callPackage ../applications/audio/qsynth { };

  qtox = callPackage ../applications/networking/instant-messengers/qtox { };

  qtpfsgui = callPackage ../applications/graphics/qtpfsgui { };

  qtractor = callPackage ../applications/audio/qtractor { };

  quodlibet = callPackage ../applications/audio/quodlibet {
    inherit (pythonPackages) mutagen;
  };

  quodlibet-with-gst-plugins = callPackage ../applications/audio/quodlibet {
    inherit (pythonPackages) mutagen;
    withGstPlugins = true;
    gst_plugins_bad = null;
  };

  rakarrack = callPackage ../applications/audio/rakarrack {
    inherit (xorg) libXpm libXft;
    fltk = fltk13;
  };

  rapcad = callPackage ../applications/graphics/rapcad {};

  rapidsvn = callPackage ../applications/version-management/rapidsvn { };

  ratpoison = callPackage ../applications/window-managers/ratpoison { };

  rawtherapee = callPackage ../applications/graphics/rawtherapee {
    fftw = fftwSinglePrec;
  };

  rcs = callPackage ../applications/version-management/rcs { };

  rdesktop = callPackage ../applications/networking/remote/rdesktop { };

  recode = callPackage ../tools/text/recode { };

  retroshare = callPackage ../applications/networking/p2p/retroshare {
    qt = qt4;
  };

  retroshare06 = lowPrio (callPackage ../applications/networking/p2p/retroshare/0.6.nix {
    qt = qt4;
  });

  rsync = callPackage ../applications/networking/sync/rsync {
    enableACLs = !(stdenv.isDarwin || stdenv.isSunOS || stdenv.isFreeBSD);
    enableCopyDevicesPatch = (config.rsync.enableCopyDevicesPatch or false);
  };

  rtl-sdr = callPackage ../applications/misc/rtl-sdr { };

  rubyripper = callPackage ../applications/audio/rubyripper {};

  rxvt = callPackage ../applications/misc/rxvt { };

  # = urxvt
  rxvt_unicode = callPackage ../applications/misc/rxvt_unicode {
    perlSupport = true;
    gdkPixbufSupport = true;
    unicode3Support = true;
  };

  # urxvt plugins
  urxvt_perls = callPackage ../applications/misc/rxvt_unicode-plugins/urxvt-perls { };
  urxvt_tabbedex = callPackage ../applications/misc/rxvt_unicode-plugins/urxvt-tabbedex { };

  rxvt_unicode_with-plugins = callPackage ../applications/misc/rxvt_unicode/wrapper.nix {
    plugins = [ urxvt_perls urxvt_tabbedex ];
  };

  sakura = callPackage ../applications/misc/sakura {
    inherit (gnome) vte;
  };

  sbagen = callPackage ../applications/misc/sbagen { };

  scite = callPackage ../applications/editors/scite { };

  scribus = callPackage ../applications/office/scribus {
    inherit (gnome) libart_lgpl;
  };

  seafile-client = callPackage ../applications/networking/seafile-client { };

  seeks = callPackage ../tools/networking/p2p/seeks { };

  seg3d = callPackage ../applications/graphics/seg3d {
    wxGTK = wxGTK28.override { unicode = false; };
  };

  seq24 = callPackage ../applications/audio/seq24 { };

  setbfree = callPackage ../applications/audio/setbfree { };

  sflphone = callPackage ../applications/networking/instant-messengers/sflphone {
    gtk = gtk3;
  };

  siproxd = callPackage ../applications/networking/siproxd { };

  skype = callPackage_i686 ../applications/networking/instant-messengers/skype { };

  skype4pidgin = callPackage ../applications/networking/instant-messengers/pidgin-plugins/skype4pidgin { };

  skype_call_recorder = callPackage ../applications/networking/instant-messengers/skype-call-recorder { };

  slrn = callPackage ../applications/networking/newsreaders/slrn { };

  spideroak = callPackage ../applications/networking/spideroak { };

  ssvnc = callPackage ../applications/networking/remote/ssvnc { };

  st = callPackage ../applications/misc/st {
    conf = config.st.conf or null;
  };

  stella = callPackage ../misc/emulators/stella { };

  linuxstopmotion = callPackage ../applications/video/linuxstopmotion { };

  sweethome3d = recurseIntoAttrs (  (callPackage ../applications/misc/sweethome3d { })
                                 // (callPackage ../applications/misc/sweethome3d/editors.nix {
                                      sweethome3dApp = sweethome3d.application;
                                    })
                                 );

  sxiv = callPackage ../applications/graphics/sxiv { };

  bittorrentSync = callPackage ../applications/networking/bittorrentsync { };

  copy-com = callPackage ../applications/networking/copy-com { };

  dropbox = callPackage ../applications/networking/dropbox { };

  dropbox-cli = callPackage ../applications/networking/dropbox-cli { };

  lightdm = callPackage ../applications/display-managers/lightdm { };

  lightdm_gtk_greeter = callPackage ../applications/display-managers/lightdm-gtk-greeter { };

  # slic3r 0.9.10b says: "Running Slic3r under Perl >= 5.16 is not supported nor recommended"
  slic3r = callPackage ../applications/misc/slic3r {
    perlPackages = perl514Packages;
    perl = perl514;
  };

  curaengine = callPackage ../applications/misc/curaengine { };

  cura = callPackage ../applications/misc/cura { };

  printrun = callPackage ../applications/misc/printrun { };

  slim = callPackage ../applications/display-managers/slim {
    libpng = libpng12;
  };


  smartgithg = callPackage ../applications/version-management/smartgithg { };

  slimThemes = recurseIntoAttrs (import ../applications/display-managers/slim/themes.nix {
    inherit stdenv fetchurl slim;
  });

  smartdeblur = callPackage ../applications/graphics/smartdeblur { };

  snapper = callPackage ../tools/misc/snapper {
    btrfsProgs = btrfsProgs-3_16;
  };

  snd = callPackage ../applications/audio/snd { };

  shntool = callPackage ../applications/audio/shntool { };

  sonic_visualiser = callPackage ../applications/audio/sonic-visualiser {
    inherit (pkgs.vamp) vampSDK;
    inherit (pkgs.xlibs) libX11;
    fftw = pkgs.fftwSinglePrec;
  };

  sox = callPackage ../applications/misc/audio/sox { };

  soxr = callPackage ../applications/misc/audio/soxr { };

  spotify = callPackage ../applications/audio/spotify {
    inherit (gnome) GConf;
    libpng = libpng12;
  };

  libspotify = callPackage ../development/libraries/libspotify {
    apiKey = config.libspotify.apiKey or null;
  };

  src = callPackage ../applications/version-management/src/default.nix {
    git = gitMinimal;
  };

  stalonetray = callPackage ../applications/window-managers/stalonetray {};

  stp = callPackage ../applications/science/logic/stp {};

  stumpwm = callPackage ../applications/window-managers/stumpwm {
    stumpwmContrib = callPackage ../applications/window-managers/stumpwm/contrib.nix { };
  };

  sublime = callPackage ../applications/editors/sublime { };

  sublime3 = lowPrio (callPackage ../applications/editors/sublime3 { });

  subversion = callPackage ../applications/version-management/subversion/default.nix {
    bdbSupport = true;
    httpServer = false;
    httpSupport = true;
    pythonBindings = false;
    perlBindings = false;
    javahlBindings = false;
    saslSupport = false;
    sasl = cyrus_sasl;
  };

  subversionClient = appendToName "client" (subversion.override {
    bdbSupport = false;
    perlBindings = true;
    pythonBindings = true;
  });

  surf = callPackage ../applications/misc/surf {
    webkit = webkitgtk2;
  };

  svk = perlPackages.SVK;

  swh_lv2 = callPackage ../applications/audio/swh-lv2 { };

  sylpheed = callPackage ../applications/networking/mailreaders/sylpheed {
    sslSupport = true;
    gpgSupport = true;
  };

  symlinks = callPackage ../tools/system/symlinks { };

  syncthing = callPackage ../applications/networking/syncthing { };

  # linux only by now
  synergy = callPackage ../applications/misc/synergy { };

  tabbed = callPackage ../applications/window-managers/tabbed { };

  tagainijisho = callPackage ../applications/office/tagainijisho {};

  tahoelafs = callPackage ../tools/networking/p2p/tahoe-lafs {
    inherit (pythonPackages) twisted foolscap simplejson nevow zfec
      pycryptopp sqlite3 darcsver setuptoolsTrial setuptoolsDarcs
      numpy pyasn1 mock;
  };

  tailor = builderDefsPackage (import ../applications/version-management/tailor) {
    inherit makeWrapper python;
  };

  tangogps = callPackage ../applications/misc/tangogps {
    gconf = gnome.GConf;
  };

  teamspeak_client = callPackage ../applications/networking/instant-messengers/teamspeak/client.nix { };
  teamspeak_server = callPackage ../applications/networking/instant-messengers/teamspeak/server.nix { };

  taskjuggler = callPackage ../applications/misc/taskjuggler { };

  taskwarrior = callPackage ../applications/misc/taskwarrior { };

  taskserver = callPackage ../servers/misc/taskserver { };

  telegram-cli = callPackage ../applications/networking/instant-messengers/telegram-cli/default.nix { };

  telepathy_gabble = callPackage ../applications/networking/instant-messengers/telepathy/gabble { };

  telepathy_haze = callPackage ../applications/networking/instant-messengers/telepathy/haze {};

  telepathy_logger = callPackage ../applications/networking/instant-messengers/telepathy/logger {};

  telepathy_mission_control = callPackage ../applications/networking/instant-messengers/telepathy/mission-control { };

  telepathy_rakia = callPackage ../applications/networking/instant-messengers/telepathy/rakia { };

  telepathy_salut = callPackage ../applications/networking/instant-messengers/telepathy/salut {};

  terminator = callPackage ../applications/misc/terminator {
    vte = gnome.vte.override { pythonSupport = true; };
    inherit (pythonPackages) notify;
  };

  termite = callPackage ../applications/misc/termite {
    gtk = gtk3;
    vte = gnome3_12.vte-select-text;
   };

  tesseract = callPackage ../applications/graphics/tesseract { };

  thinkingRock = callPackage ../applications/misc/thinking-rock { };

  thunderbird = callPackage ../applications/networking/mailreaders/thunderbird {
    inherit (gnome) libIDL;
    inherit (pythonPackages) pysqlite;
    libpng = libpng_apng;
  };

  thunderbird-bin = callPackage ../applications/networking/mailreaders/thunderbird-bin {
    gconf = pkgs.gnome.GConf;
    inherit (pkgs.gnome) libgnome libgnomeui;
    inherit (pkgs.xlibs) libX11 libXScrnSaver libXext
      libXinerama libXrender libXt;
  };

  tig = gitAndTools.tig;

  tilda = callPackage ../applications/misc/tilda {
    vte = gnome3.vte;
    gtk = gtk3;
  };

  timidity = callPackage ../tools/misc/timidity { };

  tint2 = callPackage ../applications/misc/tint2 { };

  tkcvs = callPackage ../applications/version-management/tkcvs { };

  tla = callPackage ../applications/version-management/arch { };

  todo-txt-cli = callPackage ../applications/office/todo.txt-cli { };

  tomahawk = callPackage ../applications/audio/tomahawk {
    inherit (pkgs.kde4) kdelibs;
    enableXMPP      = config.tomahawk.enableXMPP      or true;
    enableKDE       = config.tomahawk.enableKDE       or false;
    enableTelepathy = config.tomahawk.enableTelepathy or false;
  };

  torchat = callPackage ../applications/networking/instant-messengers/torchat {
    wrapPython = pythonPackages.wrapPython;
  };

  toxic = callPackage ../applications/networking/instant-messengers/toxic { };

  transcode = callPackage ../applications/audio/transcode { };

  transmission = callPackage ../applications/networking/p2p/transmission { };
  transmission_gtk = transmission.override { enableGTK3 = true; };

  transmission_remote_gtk = callPackage ../applications/networking/p2p/transmission-remote-gtk {};

  trayer = callPackage ../applications/window-managers/trayer { };

  tree = callPackage ../tools/system/tree {};

  trezor-bridge = callPackage ../applications/networking/browsers/mozilla-plugins/trezor { };

  tribler = callPackage ../applications/networking/p2p/tribler { };

  twister = callPackage ../applications/networking/p2p/twister { };

  twmn = callPackage ../applications/misc/twmn { };

  twinkle = callPackage ../applications/networking/instant-messengers/twinkle { };

  umurmur = callPackage ../applications/networking/umurmur { };

  unison = callPackage ../applications/networking/sync/unison {
    inherit (ocamlPackages) lablgtk;
    enableX11 = config.unison.enableX11 or true;
  };

  uucp = callPackage ../tools/misc/uucp { };

  uvccapture = callPackage ../applications/video/uvccapture { };

  uwimap = callPackage ../tools/networking/uwimap { };

  uzbl = callPackage ../applications/networking/browsers/uzbl {
    webkit = webkitgtk2;
  };

  utox = callPackage ../applications/networking/instant-messengers/utox { };

  vanitygen = callPackage ../applications/misc/vanitygen { };

  vanubi = callPackage ../applications/editors/vanubi { };

  vbindiff = callPackage ../applications/editors/vbindiff { };

  vcprompt = callPackage ../applications/version-management/vcprompt { };

  vdpauinfo = callPackage ../tools/X11/vdpauinfo { };

  veracity = callPackage ../applications/version-management/veracity {};

  viewMtn = builderDefsPackage (import ../applications/version-management/viewmtn/0.10.nix)
  {
    inherit monotone cheetahTemplate highlight ctags
      makeWrapper graphviz which python;
    flup = pythonPackages.flup;
  };

  vim = callPackage ../applications/editors/vim { };

  macvim = callPackage ../applications/editors/vim/macvim.nix { stdenv = clangStdenv; };

  vimHugeX = vim_configurable;

  vim_configurable = vimrc.makeCustomizable (callPackage ../applications/editors/vim/configurable.nix {
    inherit (pkgs) fetchurl fetchhg stdenv ncurses pkgconfig gettext
      composableDerivation lib config glib gtk python perl tcl ruby;
    inherit (pkgs.xlibs) libX11 libXext libSM libXpm libXt libXaw libXau libXmu
      libICE;

    features = "huge"; # one of  tiny, small, normal, big or huge
    lua = pkgs.lua5_1;
    gui = config.vim.gui or "auto";

    # optional features by flags
    flags = [ "python" "X11" ]; # only flag "X11" by now

    # so that we can use gccApple if we're building on darwin
    inherit stdenvAdapters gccApple;
  });

  vimNox = lowPrio (vim_configurable.override { source = "vim-nox"; });

  qpdfview = callPackage ../applications/misc/qpdfview {};

  qvim = lowPrio (callPackage ../applications/editors/vim/qvim.nix {
    inherit (pkgs) fetchgit stdenv ncurses pkgconfig gettext
      composableDerivation lib config python perl tcl ruby qt4;
    inherit (pkgs.xlibs) libX11 libXext libSM libXpm libXt libXaw libXau libXmu
      libICE;

    inherit (pkgs) stdenvAdapters gccApple;

    features = "huge"; # one of  tiny, small, normal, big or huge
    lua = pkgs.lua5;
    flags = [ "python" "X11" ]; # only flag "X11" by now
  });

  vimpc = callPackage ../applications/audio/vimpc { };

  virtviewer = callPackage ../applications/virtualization/virt-viewer {
    gtkvnc = gtkvnc.override { enableGTK3 = true; };
    spice_gtk = spice_gtk.override { enableGTK3 = true; };
  };
  virtmanager = callPackage ../applications/virtualization/virt-manager {
    inherit (gnome) gnome_python;
    vte = gnome3.vte;
    dconf = gnome3.dconf;
    gtkvnc = gtkvnc.override { enableGTK3 = true; };
    spice_gtk = spice_gtk.override { enableGTK3 = true; };
  };

  virtinst = callPackage ../applications/virtualization/virtinst {};

  virtualgl = callPackage ../tools/X11/virtualgl { };

  bumblebee = callPackage ../tools/X11/bumblebee { };

  vkeybd = callPackage ../applications/audio/vkeybd {
    inherit (xlibs) libX11;
  };

  vlc = callPackage ../applications/video/vlc {
    ffmpeg = ffmpeg_2_3;
  };

  vmpk = callPackage ../applications/audio/vmpk { };

  vnstat = callPackage ../applications/networking/vnstat { };

  vorbisTools = callPackage ../applications/audio/vorbis-tools { };

  vue = callPackage ../applications/misc/vue {
    jre = icedtea7_jre;
  };

  vwm = callPackage ../applications/window-managers/vwm { };

  vym = callPackage ../applications/misc/vym { };

  w3m = callPackage ../applications/networking/browsers/w3m {
    graphicsSupport = false;
  };

  weechat = callPackage ../applications/networking/irc/weechat { };

  weechatDevel = lowPrio (callPackage ../applications/networking/irc/weechat/devel.nix { });

  westonLite = callPackage ../applications/window-managers/weston {
    pango = null;
    freerdp = null;
    libunwind = null;
    vaapi = null;
    libva = null;
    libwebp = null;
  };

  weston = callPackage ../applications/window-managers/weston {
    freerdp = freerdpUnstable;
  };

  windowmaker = callPackage ../applications/window-managers/windowmaker { };

  winswitch = callPackage ../tools/X11/winswitch { };

  wings = callPackage ../applications/graphics/wings {
    erlang = erlangR14;
    esdl = esdl.override { erlang = erlangR14; };
  };

  wmname = callPackage ../applications/misc/wmname { };

  wmctrl = callPackage ../tools/X11/wmctrl { };

  # I'm keen on wmiimenu only  >wmii-3.5 no longer has it...
  wmiimenu = import ../applications/window-managers/wmii31 {
    libixp = libixp_for_wmii;
    inherit fetchurl /* fetchhg */ stdenv gawk;
    inherit (xlibs) libX11;
  };

  wmiiSnap = import ../applications/window-managers/wmii {
    libixp = libixp_for_wmii;
    inherit fetchurl /* fetchhg */ stdenv gawk;
    inherit (xlibs) libX11 xextproto libXt libXext;
    includeUnpack = config.stdenv.includeUnpack or false;
  };

  wordnet = callPackage ../applications/misc/wordnet { };

  wrapFirefox =
    { browser, browserName ? "firefox", desktopName ? "Firefox", nameSuffix ? ""
    , icon ? "${browser}/lib/${browser.name}/browser/icons/mozicon128.png" }:
    let
      cfg = stdenv.lib.attrByPath [ browserName ] {} config;
      enableAdobeFlash = cfg.enableAdobeFlash or false;
      enableGnash = cfg.enableGnash or false;
      jre = cfg.jre or false;
      icedtea = cfg.icedtea or false;
    in
    import ../applications/networking/browsers/firefox/wrapper.nix {
      inherit stdenv lib makeWrapper makeDesktopItem browser browserName desktopName nameSuffix icon;
      plugins =
         assert !(enableGnash && enableAdobeFlash);
         assert !(jre && icedtea);
         ([ ]
          ++ lib.optional enableGnash gnash
          ++ lib.optional enableAdobeFlash flashplayer
          ++ lib.optional (cfg.enableDjvu or false) (djview4)
          ++ lib.optional (cfg.enableMPlayer or false) (MPlayerPlugin browser)
          ++ lib.optional (cfg.enableGeckoMediaPlayer or false) gecko_mediaplayer
          ++ lib.optional (supportsJDK && jre && jrePlugin ? mozillaPlugin) jrePlugin
          ++ lib.optional icedtea icedtea7_web
          ++ lib.optional (cfg.enableGoogleTalkPlugin or false) google_talk_plugin
          ++ lib.optional (cfg.enableFriBIDPlugin or false) fribid
          ++ lib.optional (cfg.enableGnomeExtensions or false) gnome3.gnome_shell
          ++ lib.optional (cfg.enableTrezor or false) trezor-bridge
         );
      libs = [ gstreamer gst_plugins_base ] ++ lib.optionals (cfg.enableQuakeLive or false)
             (with xlibs; [ stdenv.gcc libX11 libXxf86dga libXxf86vm libXext libXt alsaLib zlib ]);
      gtk_modules = [ libcanberra ];
    };

  retroArchCores =
    let
      cfg = config.retroarch or {};
      inherit (lib) optional;
    in with libretro;
      ([ ]
      ++ optional (cfg.enable4do or false) _4do
      ++ optional (cfg.enableBsnesMercury or false) bsnes-mercury
      ++ optional (cfg.enableDesmume or false) desmume
      ++ optional (cfg.enableFBA or false) fba
      ++ optional (cfg.enableFceumm or false) fceumm
      ++ optional (cfg.enableGambatte or false) gambatte
      ++ optional (cfg.enableGenesisPlusGX or false) genesis-plus-gx
      ++ optional (cfg.enableMednafenPCEFast or false) mednafen-pce-fast
      ++ optional (cfg.enableMupen64Plus or false) mupen64plus
      ++ optional (cfg.enableNestopia or false) nestopia
      ++ optional (cfg.enablePicodrive or false) picodrive
      ++ optional (cfg.enablePrboom or false) prboom
      ++ optional (cfg.enablePPSSPP or false) ppsspp
      ++ optional (cfg.enableQuickNES or false) quicknes
      ++ optional (cfg.enableScummVM or false) scummvm
      ++ optional (cfg.enableSnes9x or false) snes9x
      ++ optional (cfg.enableSnes9xNext or false) snes9x-next
      ++ optional (cfg.enableStella or false) stella
      ++ optional (cfg.enableVbaNext or false) vba-next
      ++ optional (cfg.enableVbaM or false) vba-m
      );

  wrapRetroArch = { retroarch }: import ../misc/emulators/retroarch/wrapper.nix {
    inherit stdenv lib makeWrapper retroarch;
    cores = retroArchCores;
  };

  wrapXBMC = { xbmc }: import ../applications/video/xbmc/wrapper.nix {
    inherit stdenv lib makeWrapper xbmc;
    plugins = let inherit (lib) optional; in with xbmcPlugins;
      ([]
      ++ optional (config.xbmc.enableAdvancedLauncher or false) advanced-launcher
      ++ optional (config.xbmc.enableGenesis or false) genesis
      ++ optional (config.xbmc.enableSVTPlay or false) svtplay
      );
  };

  wxhexeditor = callPackage ../applications/editors/wxhexeditor { };

  wxcam = callPackage ../applications/video/wxcam {
    inherit (gnome) libglade;
    inherit intltool;
    wxGTK = wxGTK28;
    gtk = gtk2;
  };

  x11vnc = callPackage ../tools/X11/x11vnc { };

  x2vnc = callPackage ../tools/X11/x2vnc { };

  xaos = builderDefsPackage (import ../applications/graphics/xaos) {
    inherit (xlibs) libXt libX11 libXext xextproto xproto;
    inherit gsl aalib zlib intltool gettext perl;
    libpng = libpng12;
  };

  xara = callPackage ../applications/graphics/xara { };

  xawtv = callPackage ../applications/video/xawtv { };

  xbindkeys = callPackage ../tools/X11/xbindkeys { };

  xbmcPlain = callPackage ../applications/video/xbmc {
    ffmpeg = ffmpeg_1;
  };

  xbmcPlugins = recurseIntoAttrs (callPackage ../applications/video/xbmc/plugins.nix {
    xbmc = xbmcPlain;
  });

  xbmc = wrapXBMC {
    xbmc = xbmcPlain;
  };

  xbmc-retroarch-advanced-launchers =
    callPackage ../misc/emulators/retroarch/xbmc-advanced-launchers.nix {
      cores = retroArchCores;
    };

  xca = callPackage ../applications/misc/xca { };

  xcalib = callPackage ../tools/X11/xcalib { };

  xcape = callPackage ../tools/X11/xcape { };

  xchainkeys = callPackage ../tools/X11/xchainkeys { };

  xchat = callPackage ../applications/networking/irc/xchat { };

  xchm = callPackage ../applications/misc/xchm { };

  xcompmgr = callPackage ../applications/window-managers/xcompmgr { };

  compton = callPackage ../applications/window-managers/compton { };

  xdaliclock = callPackage ../tools/misc/xdaliclock {};

  xdg-user-dirs = callPackage ../tools/X11/xdg-user-dirs { };

  xdg_utils = callPackage ../tools/X11/xdg-utils { };

  xdotool = callPackage ../tools/X11/xdotool { };

  xen = callPackage ../applications/virtualization/xen {
    stdenv = overrideGCC stdenv gcc45;
  };

  xfe = callPackage ../applications/misc/xfe {
    fox = fox_1_6;
  };

  xfig = callPackage ../applications/graphics/xfig { };

  xineUI = callPackage ../applications/video/xine-ui { };

  xneur_0_13 = callPackage ../applications/misc/xneur { };

  xneur_0_8 = callPackage ../applications/misc/xneur/0.8.nix { };

  xneur = xneur_0_13;

  gxneur = callPackage ../applications/misc/gxneur  {
    inherit (gnome) libglade GConf;
  };

  xiphos = callPackage ../applications/misc/xiphos {
    gconf = gnome2.GConf;
    inherit (gnome2) gtkhtml libgtkhtml libglade scrollkeeper;
    python = python27;
    webkitgtk = webkitgtk2;
  };

  xournal = callPackage ../applications/graphics/xournal {
    inherit (gnome) libgnomeprint libgnomeprintui libgnomecanvas;
  };

  xpdf = callPackage ../applications/misc/xpdf {
    motif = lesstif;
    base14Fonts = "${ghostscript}/share/ghostscript/fonts";
  };

  xkb_switch = callPackage ../tools/X11/xkb-switch { };

  xmonad_log_applet_gnome2 = callPackage ../applications/window-managers/xmonad-log-applet {
    desktopSupport = "gnome2";
    inherit (xfce) libxfce4util xfce4panel;
    gnome2_panel = gnome2.gnome_panel;
    GConf2 = gnome2.GConf;
  };

  xmonad_log_applet_gnome3 = callPackage ../applications/window-managers/xmonad-log-applet {
    desktopSupport = "gnome3";
    inherit (xfce) libxfce4util xfce4panel;
    gnome2_panel = gnome2.gnome_panel;
    GConf2 = gnome2.GConf;
  };

  xmonad_log_applet_xfce = callPackage ../applications/window-managers/xmonad-log-applet {
    desktopSupport = "xfce4";
    inherit (xfce) libxfce4util xfce4panel;
    gnome2_panel = gnome2.gnome_panel;
    GConf2 = gnome2.GConf;
  };

  libxpdf = callPackage ../applications/misc/xpdf/libxpdf.nix { };

  xpra = callPackage ../tools/X11/xpra { };

  xrestop = callPackage ../tools/X11/xrestop { };

  xscreensaver = callPackage ../misc/screensavers/xscreensaver {
    inherit (gnome) libglade;
  };

  xsynth_dssi = callPackage ../applications/audio/xsynth-dssi { };

  xterm = callPackage ../applications/misc/xterm { };

  finalterm = callPackage ../applications/misc/finalterm { };

  roxterm = callPackage ../applications/misc/roxterm {
    inherit (pythonPackages) lockfile;
    inherit (gnome3) vte gsettings_desktop_schemas;
  };

  xtrace = callPackage ../tools/X11/xtrace { };

  xlaunch = callPackage ../tools/X11/xlaunch { };

  xmacro = callPackage ../tools/X11/xmacro { };

  xmove = callPackage ../applications/misc/xmove { };

  xmp = callPackage ../applications/audio/xmp { };

  xnee = callPackage ../tools/X11/xnee { };

  xvidcap = callPackage ../applications/video/xvidcap {
    inherit (gnome) scrollkeeper libglade;
  };

  yate = callPackage ../applications/misc/yate { };

  inherit (gnome3) yelp;

  qgis = callPackage ../applications/gis/qgis {};

  qtbitcointrader = callPackage ../applications/misc/qtbitcointrader {
    qt = qt4;
  };

  ykpers = callPackage ../applications/misc/ykpers {};

  yoshimi = callPackage ../applications/audio/yoshimi {
    fltk = fltk13;
  };

  zathuraCollection = recurseIntoAttrs
    (let callPackage = newScope pkgs.zathuraCollection; in
      import ../applications/misc/zathura {
        inherit callPackage pkgs fetchurl;
        stdenv = overrideGCC stdenv gcc49;
        useMupdf = config.zathura.useMupdf or false;
      });

  zathura = zathuraCollection.zathuraWrapper;

  zed = callPackage ../applications/editors/zed { };

  zeroc_ice = callPackage ../development/libraries/zeroc-ice { };

  girara = callPackage ../applications/misc/girara {
    gtk = gtk3;
    stdenv = overrideGCC stdenv gcc49;
  };

  girara-light = callPackage ../applications/misc/girara {
    gtk = gtk3;
    withBuildColors = false;
    ncurses = null;
  };

  zgrviewer = callPackage ../applications/graphics/zgrviewer {};

  zim = callPackage ../applications/office/zim {
    pygtk = pyGtkGlade;
  };

  zotero = callPackage ../applications/office/zotero { };

  zynaddsubfx = callPackage ../applications/audio/zynaddsubfx { };

  ### GAMES

  alienarena = callPackage ../games/alienarena { };

  andyetitmoves = if stdenv.isLinux then callPackage ../games/andyetitmoves {} else null;

  anki = callPackage ../games/anki { };

  asc = callPackage ../games/asc {
    lua = lua5_1;
    libsigcxx = libsigcxx12;
  };

  astromenace = callPackage ../games/astromenace { };

  atanks = callPackage ../games/atanks {};

  ballAndPaddle = callPackage ../games/ball-and-paddle {
    guile = guile_1_8;
  };

  bitsnbots = callPackage ../games/bitsnbots {
    lua = lua5;
  };

  blackshades = callPackage ../games/blackshades { };

  blackshadeselite = callPackage ../games/blackshadeselite { };

  blobby = callPackage ../games/blobby { };

  bsdgames = callPackage ../games/bsdgames { };

  btanks = callPackage ../games/btanks { };

  bzflag = callPackage ../games/bzflag { };

  castle_combat = callPackage ../games/castle-combat { };

  chessdb = callPackage ../games/chessdb { };

  construoBase = lowPrio (callPackage ../games/construo {
    mesa = null;
    freeglut = null;
  });

  construo = construoBase.override {
    inherit mesa freeglut;
  };

  crack_attack = callPackage ../games/crack-attack { };

  crafty = callPackage ../games/crafty { };
  craftyFull = appendToName "full" (crafty.override { fullVariant = true; });

  crrcsim = callPackage ../games/crrcsim {};

  dhewm3 = callPackage ../games/dhewm3 {};

  drumkv1 = callPackage ../applications/audio/drumkv1 { };

  dwarf_fortress = callPackage_i686 ../games/dwarf-fortress {
    SDL_image = pkgsi686Linux.SDL_image.override {
      libpng = pkgsi686Linux.libpng12;
    };
  };

  dwarf-therapist = callPackage ../games/dwarf-therapist { };

  d1x_rebirth = callPackage ../games/d1x-rebirth { };

  d2x_rebirth = callPackage ../games/d2x-rebirth { };

  eboard = callPackage ../games/eboard { };

  eduke32 = callPackage ../games/eduke32 { };

  egoboo = callPackage ../games/egoboo { };

  exult = callPackage ../games/exult { };

  fairymax = callPackage ../games/fairymax {};

  flightgear = callPackage ../games/flightgear { };

  freeciv = callPackage ../games/freeciv { };

  freeciv_gtk = callPackage ../games/freeciv {
    gtkClient = true;
    sdlClient = false;
  };

  freedink = callPackage ../games/freedink { };

  fsg = callPackage ../games/fsg {
    wxGTK = wxGTK28.override { unicode = false; };
  };

  gemrb = callPackage ../games/gemrb { };

  gl117 = callPackage ../games/gl-117 {};

  glestae = callPackage ../games/glestae {};

  globulation2 = callPackage ../games/globulation {
    boost = boost155;
  };

  gltron = callPackage ../games/gltron { };

  gnuchess = callPackage ../games/gnuchess { };

  gnugo = callPackage ../games/gnugo { };

  gtypist = callPackage ../games/gtypist { };

  hedgewars = callPackage ../games/hedgewars {
    inherit (haskellPackages) ghc network vector utf8String bytestringShow
      random hslogger dataenc;
  };

  hexen = callPackage ../games/hexen { };

  icbm3d = callPackage ../games/icbm3d { };

  ingen = callPackage ../applications/audio/ingen {
    boost = boost155;
  };

  instead = callPackage ../games/instead {
    lua = lua5;
  };

  kobodeluxe = callPackage ../games/kobodeluxe { };

  lincity = builderDefsPackage (import ../games/lincity) {
    inherit (xlibs) libX11 libXext xextproto
      libICE libSM xproto;
    inherit libpng zlib;
  };

  lincity_ng = callPackage ../games/lincity/ng.nix {};

  mars = callPackage ../games/mars { };

  megaglest = callPackage ../games/megaglest {};

  micropolis = callPackage ../games/micropolis { };

  mnemosyne = callPackage ../games/mnemosyne {
    inherit (pythonPackages) matplotlib cherrypy sqlite3;
  };

  n2048 = callPackage ../games/n2048 {};

  naev = callPackage ../games/naev { };

  nexuiz = callPackage ../games/nexuiz { };

  njam = callPackage ../games/njam { };

  oilrush = callPackage ../games/oilrush { };

  openra = callPackage ../games/openra { lua = lua5_1; };

  openttd = callPackage ../games/openttd {
    zlib = zlibStatic;
  };

  opentyrian = callPackage ../games/opentyrian { };

  openxcom = callPackage ../games/openxcom { };

  pingus = callPackage ../games/pingus {};

  pioneers = callPackage ../games/pioneers { };

  pong3d = callPackage ../games/pong3d { };

  prboom = callPackage ../games/prboom { };

  quake3demo = callPackage ../games/quake3/wrapper {
    name = "quake3-demo-${quake3game.name}";
    description = "Demo of Quake 3 Arena, a classic first-person shooter";
    game = quake3game;
    paks = [quake3demodata];
  };

  quake3demodata = callPackage ../games/quake3/demo { };

  quake3game = callPackage ../games/quake3/game { };

  quantumminigolf = callPackage ../games/quantumminigolf {};

  racer = callPackage ../games/racer { };

  residualvm = callPackage ../games/residualvm {
    openglSupport = mesaSupported;
  };

  rigsofrods = callPackage ../games/rigsofrods {
    mygui = myguiSvn;
  };

  rili = callPackage ../games/rili { };

  rogue = callPackage ../games/rogue { };

  saga = callPackage ../applications/gis/saga { };

  samplv1 = callPackage ../applications/audio/samplv1 { };

  sauerbraten = callPackage ../games/sauerbraten {};

  scid = callPackage ../games/scid { };

  scummvm = callPackage ../games/scummvm { };

  scorched3d = callPackage ../games/scorched3d { };

  sdlmame = callPackage ../games/sdlmame { };

  sgtpuzzles = builderDefsPackage (import ../games/sgt-puzzles) {
    inherit pkgconfig fetchsvn perl gtk;
    inherit (xlibs) libX11;
  };

  simutrans = callPackage ../games/simutrans { };

  soi = callPackage ../games/soi {};

  # You still can override by passing more arguments.
  spaceOrbit = callPackage ../games/orbit { };

  spring = callPackage ../games/spring {
    boost = boost155;
  };

  springLobby = callPackage ../games/spring/springlobby.nix { };

  stardust = callPackage ../games/stardust {};

  steam = callPackage ../games/steam {};

  steamChrootEnv = callPackage ../games/steam/chrootenv.nix { };

  stuntrally = callPackage ../games/stuntrally { };

  superTux = callPackage ../games/super-tux { };

  superTuxKart = callPackage ../games/super-tux-kart { };

  synthv1 = callPackage ../applications/audio/synthv1 { };

  tbe = callPackage ../games/the-butterfly-effect {};

  teetertorture = callPackage ../games/teetertorture { };

  teeworlds = callPackage ../games/teeworlds { };

  tennix = callPackage ../games/tennix { };

  tibia = callPackage_i686 ../games/tibia { };

  tintin = callPackage ../games/tintin { };

  tpm = callPackage ../games/thePenguinMachine { };

  tremulous = callPackage ../games/tremulous { };

  speed_dreams = callPackage ../games/speed-dreams {
    # Torcs wants to make shared libraries linked with plib libraries (it provides static).
    # i686 is the only platform I know than can do that linking without plib built with -fPIC
    plib = plib.override { enablePIC = !stdenv.isi686; };
    libpng = libpng12;
  };

  torcs = callPackage ../games/torcs {
    # Torcs wants to make shared libraries linked with plib libraries (it provides static).
    # i686 is the only platform I know than can do that linking without plib built with -fPIC
    plib = plib.override { enablePIC = !stdenv.isi686; };
  };

  trigger = callPackage ../games/trigger { };

  typespeed = callPackage ../games/typespeed { };

  ufoai = callPackage ../games/ufoai { };

  ultimatestunts = callPackage ../games/ultimatestunts { };

  ultrastardx = callPackage ../games/ultrastardx {
    ffmpeg = ffmpeg_0_6;
    lua = lua5;
  };

  unvanquished = callPackage ../games/unvanquished { };

  uqm = callPackage ../games/uqm { };

  urbanterror = callPackage ../games/urbanterror { };

  ue4demos = recurseIntoAttrs (callPackage ../games/ue4demos { });

  ut2004demo = callPackage ../games/ut2004demo { };

  vdrift = callPackage ../games/vdrift { };

  vectoroids = callPackage ../games/vectoroids { };

  vessel = callPackage_i686 ../games/vessel { };

  warmux = callPackage ../games/warmux { };

  warsow = callPackage ../games/warsow {
    libjpeg = libjpeg62;
  };

  warzone2100 = callPackage ../games/warzone2100 { };

  widelands = callPackage ../games/widelands {
    lua = lua5_1;
  };

  worldofgoo_demo = callPackage ../games/worldofgoo {
    demo = true;
  };

  worldofgoo = callPackage ../games/worldofgoo { };

  xboard =  callPackage ../games/xboard { };

  xconq = callPackage ../games/xconq {};

  # TODO: the corresponding nix file is missing
  # xracer = callPackage ../games/xracer { };

  xonotic = callPackage ../games/xonotic { };

  xskat = callPackage ../games/xskat { };

  xsnow = callPackage ../games/xsnow { };

  xsokoban = builderDefsPackage (import ../games/xsokoban) {
    inherit (xlibs) libX11 xproto libXpm libXt;
  };

  zdoom = callPackage ../games/zdoom { };

  zod = callPackage ../games/zod { };

  zoom = callPackage ../games/zoom { };

  keen4 = callPackage ../games/keen4 { };

  zeroad = callPackage ../games/0ad { };

  ### DESKTOP ENVIRONMENTS

  cinnamon = recurseIntoAttrs rec {
    callPackage = newScope pkgs.cinnamon;
    inherit (gnome3) gnome_common libgnomekbd gnome-menus zenity;

    muffin = callPackage ../desktops/cinnamon/muffin.nix { } ;

    cinnamon-control-center = callPackage ../desktops/cinnamon/cinnamon-control-center.nix{ };

    cinnamon-settings-daemon = callPackage ../desktops/cinnamon/cinnamon-settings-daemon.nix{ };

    cinnamon-session = callPackage ../desktops/cinnamon/cinnamon-session.nix{ } ;

    cinnamon-desktop = callPackage ../desktops/cinnamon/cinnamon-desktop.nix { };

    cinnamon-translations = callPackage ../desktops/cinnamon/cinnamon-translations.nix { };

    cjs = callPackage ../desktops/cinnamon/cjs.nix { };
  };

  enlightenment = callPackage ../desktops/enlightenment { };

  e17 = recurseIntoAttrs (
    let callPackage = newScope pkgs.e17; in
    import ../desktops/e17 { inherit callPackage pkgs; }
  );

  e18 = recurseIntoAttrs (
    let callPackage = newScope pkgs.e18; in
    import ../desktops/e18 { inherit callPackage pkgs; }
  );

  e19 = recurseIntoAttrs (
    let callPackage = newScope pkgs.e19; in
    import ../desktops/e19 { inherit callPackage pkgs; }
  );

  gnome2 = callPackage ../desktops/gnome-2 {
    callPackage = pkgs.newScope pkgs.gnome2;
    self = pkgs.gnome2;
  }  // pkgs.gtkLibs // {
    # Backwards compatibility;
    inherit (pkgs) libsoup libwnck gtk_doc gnome_doc_utils;
  };

  gnome3_12 = recurseIntoAttrs (callPackage ../desktops/gnome-3/3.12 {
    callPackage = pkgs.newScope pkgs.gnome3_12;
  });

  gnome3 = gnome3_12;

  gnome = recurseIntoAttrs gnome2;

  hsetroot = callPackage ../tools/X11/hsetroot { };

  kakasi = callPackage ../tools/text/kakasi { };

  kde4 = recurseIntoAttrs pkgs.kde414;

  kde414 = kdePackagesFor (pkgs.kde414 // {
      libusb = libusb1;
      libcanberra = libcanberra_kde;
    }) ../desktops/kde-4.14;

  kdePackagesFor = self: dir:
    let callPackageOrig = callPackage; in
    let
      callPackage = newScope self;
      kde4 = callPackageOrig dir {
        inherit callPackage callPackageOrig;
      };
    in kde4 // {
      inherit kde4;

      wrapper = callPackage ../build-support/kdewrapper {};

      recurseForRelease = true;

      amarok = callPackage ../applications/audio/amarok { };

      bangarang = callPackage ../applications/video/bangarang { };

      basket = callPackage ../applications/office/basket { };

      bluedevil = callPackage ../tools/bluetooth/bluedevil { };

      calligra = callPackage ../applications/office/calligra { };

      colord-kde = callPackage ../tools/misc/colord-kde { };

      digikam = if builtins.compareVersions "4.9" kde4.release == 1 then
          callPackage ../applications/graphics/digikam/2.nix { }
        else
          callPackage ../applications/graphics/digikam { };

      eventlist = callPackage ../applications/office/eventlist {};

      k3b = callPackage ../applications/misc/k3b { };

      kadu = callPackage ../applications/networking/instant-messengers/kadu { };

      kbibtex = callPackage ../applications/office/kbibtex { };

      kde_gtk_config = callPackage ../tools/misc/kde-gtk-config { };

      kde_wacomtablet = callPackage ../applications/misc/kde-wacomtablet { };

      kdeconnect = callPackage ../applications/misc/kdeconnect { };

      kdenlive = callPackage ../applications/video/kdenlive { mlt = mlt-qt4; };

      kdesvn = callPackage ../applications/version-management/kdesvn { };

      kdevelop = callPackage ../applications/editors/kdevelop { };

      kdevplatform = callPackage ../development/libraries/kdevplatform { };

      kdiff3 = callPackage ../tools/text/kdiff3 { };

      kgraphviewer = callPackage ../applications/graphics/kgraphviewer { };

      kile = callPackage ../applications/editors/kile { };

      kmplayer = callPackage ../applications/video/kmplayer { };

      kmymoney = callPackage ../applications/office/kmymoney { };

      kipi_plugins = callPackage ../applications/graphics/kipi-plugins { };

      konversation = callPackage ../applications/networking/irc/konversation { };

      kvirc = callPackage ../applications/networking/irc/kvirc { };

      krename = callPackage ../applications/misc/krename { };

      krusader = callPackage ../applications/misc/krusader { };

      ksshaskpass = callPackage ../tools/security/ksshaskpass {};

      ktorrent = callPackage ../applications/networking/p2p/ktorrent { };

      kuickshow = callPackage ../applications/graphics/kuickshow { };

      libalkimia = callPackage ../development/libraries/libalkimia { };

      libktorrent = callPackage ../development/libraries/libktorrent { };

      libkvkontakte = callPackage ../development/libraries/libkvkontakte { };

      liblikeback = callPackage ../development/libraries/liblikeback { };

      libmm-qt = callPackage ../development/libraries/libmm-qt { };

      libnm-qt = callPackage ../development/libraries/libnm-qt { };

      massif-visualizer = callPackage ../development/tools/analysis/massif-visualizer { };

      networkmanagement = callPackage ../tools/networking/networkmanagement { };

      partitionManager = callPackage ../tools/misc/partition-manager { };

      plasma-nm = callPackage ../tools/networking/plasma-nm { };

      polkit_kde_agent = callPackage ../tools/security/polkit-kde-agent { };

      psi = callPackage ../applications/networking/instant-messengers/psi { };

      qtcurve = callPackage ../misc/themes/qtcurve { };

      quassel = callPackage ../applications/networking/irc/quassel rec {
        monolithic = true;
        daemon = false;
        client = false;
        withKDE = stdenv.isLinux;
        qt = if withKDE then qt4 else qt5; # KDE supported quassel cannot build with qt5 yet (maybe in 0.12.0)
        dconf = gnome3.dconf;
      };

      quasselWithoutKDE = (self.quassel.override {
        monolithic = true;
        daemon = false;
        client = false;
        withKDE = false;
        #qt = qt5;
        tag = "-without-kde";
      });

      quasselDaemon = (self.quassel.override {
        monolithic = false;
        daemon = true;
        client = false;
        withKDE = false;
        #qt = qt5;
        tag = "-daemon";
      });

      quasselClient = (self.quassel.override {
        monolithic = false;
        daemon = false;
        client = true;
        tag = "-client";
      });

      quasselClientWithoutKDE = (self.quasselClient.override {
        monolithic = false;
        daemon = false;
        client = true;
        withKDE = false;
        #qt = qt5;
        tag = "-client-without-kde";
      });

      rekonq = callPackage ../applications/networking/browsers/rekonq { };

      kwebkitpart = callPackage ../applications/networking/browsers/kwebkitpart { };

      rsibreak = callPackage ../applications/misc/rsibreak { };

      semnotes = callPackage ../applications/misc/semnotes { };

      skrooge = callPackage ../applications/office/skrooge { };

      telepathy = callPackage ../applications/networking/instant-messengers/telepathy/kde {};

      yakuake = callPackage ../applications/misc/yakuake { };

      zanshin = callPackage ../applications/office/zanshin { };

      kwooty = callPackage ../applications/networking/newsreaders/kwooty { };
    };

  pantheon = recurseIntoAttrs rec {
    callPackage = newScope pkgs.pantheon;
    pantheon-terminal = callPackage ../desktops/pantheon/apps/pantheon-terminal { };
  };

  redshift = callPackage ../applications/misc/redshift {
    inherit (xorg) libX11 libXrandr libxcb randrproto libXxf86vm
      xf86vidmodeproto;
    inherit (gnome) GConf;
    inherit (pythonPackages) pyxdg;
    geoclue = geoclue2;
  };

  oxygen-gtk2 = callPackage ../misc/themes/gtk2/oxygen-gtk { };

  oxygen-gtk3 = callPackage ../misc/themes/gtk3/oxygen-gtk3 { };

  oxygen_gtk = oxygen-gtk2; # backwards compatibility

  gtk_engines = callPackage ../misc/themes/gtk2/gtk-engines { };

  gtk-engine-murrine = callPackage ../misc/themes/gtk2/gtk-engine-murrine { };

  gnome_themes_standard = gnome3.gnome_themes_standard;

  mate-icon-theme = callPackage ../misc/themes/mate-icon-theme { };

  mate-themes = callPackage ../misc/themes/mate-themes { };

  xfce = xfce4_10;
  xfce4_10 = recurseIntoAttrs (import ../desktops/xfce { inherit config pkgs newScope; });


  ### SCIENCE

  ### SCIENCE/GEOMETRY

  drgeo = builderDefsPackage (import ../applications/science/geometry/drgeo) {
    inherit (gnome) libglade;
    inherit libxml2 perl intltool libtool pkgconfig gtk;
    guile = guile_1_8;
  };

  tetgen = callPackage ../applications/science/geometry/tetgen { };


  ### SCIENCE/BIOLOGY

  alliance = callPackage ../applications/science/electronics/alliance {
    motif = lesstif;
  };

  arb = callPackage ../applications/science/biology/arb {
    lesstif = lesstif93;
  };

  archimedes = callPackage ../applications/science/electronics/archimedes { };

  biolib = callPackage ../development/libraries/science/biology/biolib { };

  emboss = callPackage ../applications/science/biology/emboss { };

  mrbayes = callPackage ../applications/science/biology/mrbayes { };

  ncbiCTools = builderDefsPackage ../development/libraries/ncbi {
    inherit tcsh mesa lesstif;
    inherit (xlibs) libX11 libXaw xproto libXt libSM libICE
      libXmu libXext;
  };

  ncbi_tools = callPackage ../applications/science/biology/ncbi-tools { };

  paml = callPackage ../applications/science/biology/paml { };

  pal2nal = callPackage ../applications/science/biology/pal2nal { };

  plink = callPackage ../applications/science/biology/plink/default.nix { };


  ### SCIENCE/MATH

  arpack = callPackage ../development/libraries/science/math/arpack { };

  atlas = callPackage ../development/libraries/science/math/atlas {
    # The build process measures CPU capabilities and optimizes the
    # library to perform best on that particular machine. That is a
    # great feature, but it's of limited use with pre-built binaries
    # coming from a central build farm.
    tolerateCpuTimingInaccuracy = true;
  };

  blas = callPackage ../development/libraries/science/math/blas { };

  content = builderDefsPackage ../applications/science/math/content {
    inherit mesa lesstif;
    inherit (xlibs) libX11 libXaw xproto libXt libSM libICE
      libXmu libXext libXcursor;
  };

  jags = callPackage ../applications/science/math/jags { };

  liblapack = callPackage ../development/libraries/science/math/liblapack { };
  liblapack_3_5_0 = callPackage ../development/libraries/science/math/liblapack/3.5.0.nix { };

  liblbfgs = callPackage ../development/libraries/science/math/liblbfgs { };

  # julia is pinned to specific versions of openblas, so keep old versions
  # until they aren't needed. The un-versioned attribute may continue to track
  # upstream development.
  openblas = callPackage ../development/libraries/science/math/openblas {
    liblapack = liblapack_3_5_0;
  };
  openblas_0_2_10 = callPackage ../development/libraries/science/math/openblas/0.2.10.nix {
    liblapack = liblapack_3_5_0;
  };
  openblas_0_2_2 = callPackage ../development/libraries/science/math/openblas/0.2.2.nix { };

  mathematica = callPackage ../applications/science/math/mathematica { };
  mathematica9 = callPackage ../applications/science/math/mathematica/9.nix { };

  sage = callPackage ../applications/science/math/sage { };

  ipopt = callPackage ../development/libraries/science/math/ipopt { };

  ### SCIENCE/MOLECULAR-DYNAMICS

  gromacs = callPackage ../applications/science/molecular-dynamics/gromacs {
    singlePrec = true;
    fftw = fftwSinglePrec;
    cmake = cmakeCurses;
  };

  gromacsDouble = lowPrio (callPackage ../applications/science/molecular-dynamics/gromacs {
    singlePrec = false;
    fftw = fftw;
    cmake = cmakeCurses;
  });


  ### SCIENCE/LOGIC

  abc-verifier = callPackage ../applications/science/logic/abc {};

  alt-ergo = callPackage ../applications/science/logic/alt-ergo {};

  coq = callPackage ../applications/science/logic/coq {
    inherit (ocamlPackages_4_01_0) ocaml findlib lablgtk;
    camlp5 = ocamlPackages_4_01_0.camlp5_transitional;
  };

  coq_HEAD = callPackage ../applications/science/logic/coq/HEAD.nix {
    inherit (ocamlPackages) findlib lablgtk;
    camlp5 = ocamlPackages.camlp5_transitional;
  };

  coq_8_3 = callPackage ../applications/science/logic/coq/8.3.nix {
    inherit (ocamlPackages_3_12_1) ocaml findlib;
    camlp5 = ocamlPackages_3_12_1.camlp5_transitional;
    lablgtk = ocamlPackages_3_12_1.lablgtk_2_14;
  };

  mkCoqPackages_8_4 = self: let callPackage = newScope self; in {

    bedrock = callPackage ../development/coq-modules/bedrock {};

    containers = callPackage ../development/coq-modules/containers {};

    coqExtLib = callPackage ../development/coq-modules/coq-ext-lib {};

    domains = callPackage ../development/coq-modules/domains {};

    flocq = callPackage ../development/coq-modules/flocq {};

    heq = callPackage ../development/coq-modules/heq {};

    mathcomp = callPackage ../development/coq-modules/mathcomp {};

    paco = callPackage ../development/coq-modules/paco {};

    ssreflect = callPackage ../development/coq-modules/ssreflect {};

    tlc = callPackage ../development/coq-modules/tlc {};

    unimath = callPackage ../development/coq-modules/unimath {};

    ynot = callPackage ../development/coq-modules/ynot {};

  };

  coqPackages = recurseIntoAttrs (mkCoqPackages_8_4 coqPackages);

  cvc3 = callPackage ../applications/science/logic/cvc3 {};
  cvc4 = callPackage ../applications/science/logic/cvc4 {};

  ekrhyper = callPackage ../applications/science/logic/ekrhyper {};

  eprover = callPackage ../applications/science/logic/eprover {
    texLive = texLiveAggregationFun {
      paths = [
        texLive texLiveExtra
      ];
    };
  };

  ginac = callPackage ../applications/science/math/ginac { };

  hol = callPackage ../applications/science/logic/hol { };

  hol_light = callPackage ../applications/science/logic/hol_light {
    inherit (ocamlPackages) findlib;
    camlp5 = ocamlPackages.camlp5_strict;
  };

  isabelle = import ../applications/science/logic/isabelle {
    inherit (pkgs) stdenv fetchurl nettools perl polyml;
    inherit (pkgs.emacs24Packages) proofgeneral;
    java = if stdenv.isLinux then jre else jdk;
  };

  iprover = callPackage ../applications/science/logic/iprover {};

  leo2 = callPackage ../applications/science/logic/leo2 {};

  logisim = callPackage ../applications/science/logic/logisim {};

  ltl2ba = callPackage ../applications/science/logic/ltl2ba {};

  matita = callPackage ../applications/science/logic/matita {
    ocaml = ocaml_3_11_2;
    inherit (ocamlPackages_3_11_2) findlib lablgtk ocaml_expat gmetadom ocaml_http
            lablgtkmathview ocaml_mysql ocaml_sqlite3 ocamlnet camlzip ocaml_pcre;
    ulex08 = ocamlPackages_3_11_2.ulex08.override { camlp5 = ocamlPackages_3_11_2.camlp5_old_transitional; };
  };

  matita_130312 = lowPrio (callPackage ../applications/science/logic/matita/130312.nix {
    inherit (ocamlPackages) findlib lablgtk ocaml_expat gmetadom ocaml_http
            ocaml_mysql ocamlnet ulex08 camlzip ocaml_pcre;
  });

  minisat = callPackage ../applications/science/logic/minisat {};

  opensmt = callPackage ../applications/science/logic/opensmt { };

  ott = callPackage ../applications/science/logic/ott {
    camlp5 = ocamlPackages.camlp5_transitional;
  };

  otter = callPackage ../applications/science/logic/otter {};

  picosat = callPackage ../applications/science/logic/picosat {};

  prooftree = callPackage ../applications/science/logic/prooftree {
    inherit (ocamlPackages_4_01_0) ocaml findlib lablgtk;
    camlp5 = ocamlPackages_4_01_0.camlp5_transitional;
  };

  prover9 = callPackage ../applications/science/logic/prover9 { };

  satallax = callPackage ../applications/science/logic/satallax {};

  spass = callPackage ../applications/science/logic/spass {};

  tptp = callPackage ../applications/science/logic/tptp {};

  twelf = callPackage ../applications/science/logic/twelf {
    smlnj = if stdenv.isDarwin
      then smlnjBootstrap
      else smlnj;
  };

  verifast = callPackage ../applications/science/logic/verifast {};

  why3 = callPackage ../applications/science/logic/why3 {};

  yices = callPackage ../applications/science/logic/yices {};

  z3 = callPackage ../applications/science/logic/z3 {};

  boolector   = boolector15;
  boolector15 = callPackage ../applications/science/logic/boolector {};
  boolector16 = lowPrio (callPackage ../applications/science/logic/boolector {
    useV16 = true;
  });

  ### SCIENCE / ELECTRONICS

  eagle = callPackage_i686 ../applications/science/electronics/eagle { };

  caneda = callPackage ../applications/science/electronics/caneda { };

  gtkwave = callPackage ../applications/science/electronics/gtkwave { };

  kicad = callPackage ../applications/science/electronics/kicad {
    wxGTK = wxGTK29;
  };

  ngspice = callPackage ../applications/science/electronics/ngspice { };

  qucs = callPackage ../applications/science/electronics/qucs { };

  xoscope = callPackage ../applications/science/electronics/xoscope { };


  ### SCIENCE / MATH

  ecm = callPackage ../applications/science/math/ecm { };

  eukleides = callPackage ../applications/science/math/eukleides {
    texinfo = texinfo4;
  };

  fricas = callPackage ../applications/science/math/fricas { };

  gap = callPackage ../applications/science/math/gap { };

  maxima = callPackage ../applications/science/math/maxima { };

  wxmaxima = callPackage ../applications/science/math/wxmaxima { };

  pari = callPackage ../applications/science/math/pari {};

  pcalc = callPackage ../applications/science/math/pcalc { };

  pspp = callPackage ../applications/science/math/pssp {
    inherit (gnome) libglade gtksourceview;
  };

  singular = callPackage ../applications/science/math/singular {};

  scilab = callPackage ../applications/science/math/scilab {
    withXaw3d = false;
    withTk = true;
    withGtk = false;
    withOCaml = true;
    withX = true;
  };

  msieve = callPackage ../applications/science/math/msieve { };

  weka = callPackage ../applications/science/math/weka { };

  yad = callPackage ../tools/misc/yad { };

  yacas = callPackage ../applications/science/math/yacas { };

  speedcrunch = callPackage ../applications/science/math/speedcrunch {
    qt = qt4;
    cmake = cmakeCurses;
  };


  ### SCIENCE / MISC

  boinc = callPackage ../applications/science/misc/boinc { };

  celestia = callPackage ../applications/science/astronomy/celestia {
    lua = lua5_1;
    inherit (xlibs) libXmu;
    inherit (pkgs.gnome) gtkglext;
  };

  fityk = callPackage ../applications/science/misc/fityk { };

  gravit = callPackage ../applications/science/astronomy/gravit { };

  golly = callPackage ../applications/science/misc/golly { };

  megam = callPackage ../applications/science/misc/megam { };

  root = callPackage ../applications/science/misc/root { };

  simgrid = callPackage ../applications/science/misc/simgrid { };

  spyder = callPackage ../applications/science/spyder {
    inherit (pythonPackages) pyflakes rope sphinx numpy scipy matplotlib; # recommended
    inherit (pythonPackages) ipython pep8; # optional
    inherit pylint;
  };

  stellarium = callPackage ../applications/science/astronomy/stellarium { };

  tulip = callPackage ../applications/science/misc/tulip { };

  vite = enableDebugging (callPackage ../applications/science/misc/vite { });

  xplanet = callPackage ../applications/science/astronomy/xplanet { };

  ### SCIENCE / PHYSICS

  geant4 = callPackage ../development/libraries/physics/geant4 {
    enableMultiThreading = true;
    enableG3toG4         = false;
    enableInventor       = false;
    enableGDML           = false;
    enableQT             = false;
    enableXM             = false;
    enableOpenGLX11      = true;
    enableRaytracerX11   = false;

    # Optional system packages, otherwise internal GEANT4 packages are used.
    clhep = null;
    expat = expat;
    zlib  = null;

    # For enableGDML.
    xercesc = null;

    # For enableQT.
    qt = null; # qt4SDK or qt5SDK

    # For enableXM.
    motif = null; # motif or lesstif

    # For enableQT, enableXM, enableOpenGLX11, enableRaytracerX11.
    mesa = mesa;
    x11  = x11;
    inherit (xlibs) libXmu;
  };

  g4py = callPackage ../development/libraries/physics/geant4/g4py { };

  ### MISC

  atari800 = callPackage ../misc/emulators/atari800 { };

  ataripp = callPackage ../misc/emulators/atari++ { };

  auctex = callPackage ../tools/typesetting/tex/auctex { };

  beep = callPackage ../misc/beep { };

  cups = callPackage ../misc/cups { libusb = libusb1; };

  cups_filters = callPackage ../misc/cups/filters.nix { };

  crashplan = callPackage ../applications/backup/crashplan { };

  gutenprint = callPackage ../misc/drivers/gutenprint { };

  gutenprintBin = callPackage ../misc/drivers/gutenprint/bin.nix { };

  cupsBjnp = callPackage ../misc/cups/drivers/cups-bjnp { };

  darcnes = callPackage ../misc/emulators/darcnes { };

  dbacl = callPackage ../tools/misc/dbacl { };

  dblatex = callPackage ../tools/typesetting/tex/dblatex {
    enableAllFeatures = false;
  };

  dblatexFull = appendToName "full" (dblatex.override {
    enableAllFeatures = true;
  });

  dosbox = callPackage ../misc/emulators/dosbox { };

  dpkg = callPackage ../tools/package-management/dpkg { };

  ekiga = newScope pkgs.gnome ../applications/networking/instant-messengers/ekiga { };

  emulationstation = callPackage ../misc/emulators/emulationstation { };

  electricsheep = callPackage ../misc/screensavers/electricsheep { };

  fakenes = callPackage ../misc/emulators/fakenes { };

  faust-compiler = callPackage ../applications/audio/faust-compiler { };

  fceux = callPackage ../misc/emulators/fceux { };

  foldingathome = callPackage ../misc/foldingathome { };

  foo2zjs = callPackage ../misc/drivers/foo2zjs {};

  foomatic_filters = callPackage ../misc/drivers/foomatic-filters {};

  freestyle = callPackage ../misc/freestyle { };

  gajim = callPackage ../applications/networking/instant-messengers/gajim { };

  gammu = callPackage ../applications/misc/gammu { };

  gensgs = callPackage_i686 ../misc/emulators/gens-gs { };

  ghostscript = callPackage ../misc/ghostscript {
    x11Support = false;
    cupsSupport = config.ghostscript.cups or (!stdenv.isDarwin);
  };

  ghostscriptX = appendToName "with-X" (ghostscript.override {
    x11Support = true;
  });

  guix = callPackage ../tools/package-management/guix { };

  gxemul = callPackage ../misc/gxemul { };

  hatari = callPackage ../misc/emulators/hatari { };

  hplip = callPackage ../misc/drivers/hplip { };

  hplipWithPlugin = hplip.override { withPlugin = true; };

  # using the new configuration style proposal which is unstable
  jack1 = callPackage ../misc/jackaudio/jack1.nix { };

  jack2 = callPackage ../misc/jackaudio { };

  keynav = callPackage ../tools/X11/keynav { };

  lazylist = callPackage ../tools/typesetting/tex/lazylist { };

  lilypond = callPackage ../misc/lilypond { guile = guile_1_8; };

  martyr = callPackage ../development/libraries/martyr { };

  mess = callPackage ../misc/emulators/mess {
    inherit (pkgs.gnome) GConf;
  };

  mupen64plus = callPackage ../misc/emulators/mupen64plus { };

  mupen64plus1_5 = callPackage ../misc/emulators/mupen64plus/1.5.nix { };

  nix = nixStable;

  nixStable = callPackage ../tools/package-management/nix {
    storeDir = config.nix.storeDir or "/nix/store";
    stateDir = config.nix.stateDir or "/nix/var";
  };

  nixUnstable = callPackage ../tools/package-management/nix/unstable.nix {
    storeDir = config.nix.storeDir or "/nix/store";
    stateDir = config.nix.stateDir or "/nix/var";
  };

  nixops = callPackage ../tools/package-management/nixops { };

  nix-prefetch-scripts = callPackage ../tools/package-management/nix-prefetch-scripts { };

  nix-repl = callPackage ../tools/package-management/nix-repl { };

  nut = callPackage ../applications/misc/nut { };

  solfege = callPackage ../misc/solfege {
      pysqlite = pkgs.pythonPackages.sqlite3;
  };

  disnix = callPackage ../tools/package-management/disnix { };

  dysnomia = callPackage ../tools/package-management/disnix/dysnomia {
    enableApacheWebApplication = config.disnix.enableApacheWebApplication or false;
    enableAxis2WebService = config.disnix.enableAxis2WebService or false;
    enableEjabberdDump = config.disnix.enableEjabberdDump or false;
    enableMySQLDatabase = config.disnix.enableMySQLDatabase or false;
    enablePostgreSQLDatabase = config.disnix.enablePostgreSQLDatabase or false;
    enableSubversionRepository = config.disnix.enableSubversionRepository or false;
    enableTomcatWebApplication = config.disnix.enableTomcatWebApplication or false;
  };

  disnixos = callPackage ../tools/package-management/disnix/disnixos { };

  DisnixWebService = callPackage ../tools/package-management/disnix/DisnixWebService { };

  latex2html = callPackage ../tools/typesetting/tex/latex2html/default.nix {
    tex = tetex;
  };

  lkproof = callPackage ../tools/typesetting/tex/lkproof { };

  mysqlWorkbench = newScope gnome ../applications/misc/mysql-workbench {
    lua = lua5_1;
    inherit (pythonPackages) pexpect paramiko;
  };

  robomongo = callPackage ../applications/misc/robomongo { };

  opkg = callPackage ../tools/package-management/opkg { };

  opkg-utils = callPackage ../tools/package-management/opkg-utils { };

  pgadmin = callPackage ../applications/misc/pgadmin { };

  pgf = pgf2;

  # Keep the old PGF since some documents don't render properly with
  # the new one.
  pgf1 = callPackage ../tools/typesetting/tex/pgf/1.x.nix { };

  pgf2 = callPackage ../tools/typesetting/tex/pgf/2.x.nix { };

  pgf3 = callPackage ../tools/typesetting/tex/pgf/3.x.nix { };

  pgfplots = callPackage ../tools/typesetting/tex/pgfplots { };

  phabricator = callPackage ../misc/phabricator { };

  pjsip = callPackage ../applications/networking/pjsip { };

  polytable = callPackage ../tools/typesetting/tex/polytable { };

  PPSSPP = callPackage ../misc/emulators/ppsspp { };

  uae = callPackage ../misc/emulators/uae { };

  putty = callPackage ../applications/networking/remote/putty { };

  retroarchBare = callPackage ../misc/emulators/retroarch { };

  retroarch = wrapRetroArch { retroarch = retroarchBare; };

  libretro = recurseIntoAttrs (callPackage ../misc/emulators/retroarch/cores.nix {
    retroarch = retroarchBare;
  });

  rssglx = callPackage ../misc/screensavers/rss-glx { };

  runit = callPackage ../tools/system/runit { };

  xlockmore = callPackage ../misc/screensavers/xlockmore { };

  sails = callPackage ../misc/sails { };

  samsungUnifiedLinuxDriver = import ../misc/cups/drivers/samsung {
    inherit fetchurl stdenv;
    inherit cups ghostscript glibc patchelf;
    gcc = import ../development/compilers/gcc/4.4 {
      inherit stdenv fetchurl gmp mpfr noSysDirs gettext which;
      texinfo = texinfo4;
      profiledCompiler = true;
    };
  };

  saneBackends = callPackage ../applications/graphics/sane/backends.nix {
    gt68xxFirmware = config.sane.gt68xxFirmware or null;
    snapscanFirmware = config.sane.snapscanFirmware or null;
    hotplugSupport = config.sane.hotplugSupport or true;
    libusb = libusb1;
  };

  saneBackendsGit = callPackage ../applications/graphics/sane/backends-git.nix {
    gt68xxFirmware = config.sane.gt68xxFirmware or null;
    snapscanFirmware = config.sane.snapscanFirmware or null;
    hotplugSupport = config.sane.hotplugSupport or true;
  };

  mkSaneConfig = callPackage ../applications/graphics/sane/config.nix { };

  saneFrontends = callPackage ../applications/graphics/sane/frontends.nix { };

  seafile-shared = callPackage ../misc/seafile-shared { };

  slock = callPackage ../misc/screensavers/slock { };

  soundOfSorting = callPackage ../misc/sound-of-sorting { };

  sourceAndTags = import ../misc/source-and-tags {
    inherit pkgs stdenv unzip lib ctags;
    hasktags = haskellPackages.hasktags;
  };

  splix = callPackage ../misc/cups/drivers/splix { };

  streamripper = callPackage ../applications/audio/streamripper { };

  sqsh = callPackage ../development/tools/sqsh { };

  tetex = callPackage ../tools/typesetting/tex/tetex { libpng = libpng12; };

  tex4ht = callPackage ../tools/typesetting/tex/tex4ht { };

  texFunctions = import ../tools/typesetting/tex/nix pkgs;

  texLive = builderDefsPackage (import ../tools/typesetting/tex/texlive) {
    inherit builderDefs zlib bzip2 ncurses libpng ed lesstif ruby potrace
      gd t1lib freetype icu perl expat curl xz pkgconfig zziplib texinfo
      libjpeg bison python fontconfig flex poppler libpaper graphite2
      makeWrapper gmp mpfr xpdf;
    inherit (xlibs) libXaw libX11 xproto libXt libXpm
      libXmu libXext xextproto libSM libICE;
    ghostscript = ghostscriptX;
    harfbuzz = harfbuzz.override {
      withIcu = true; withGraphite2 = true;
    };
  };

  texLiveFull = lib.setName "texlive-full" (texLiveAggregationFun {
    paths = [ texLive texLiveExtra lmodern texLiveCMSuper texLiveLatexXColor
              texLivePGF texLiveBeamer texLiveModerncv tipa tex4ht texinfo
              texLiveModerntimeline texLiveContext ];
  });

  /* Look in configurations/misc/raskin.nix for usage example (around revisions
  where TeXLive was added)

  (texLiveAggregationFun {
    paths = [texLive texLiveExtra texLiveCMSuper
      texLiveBeamer
    ];
  })

  You need to use texLiveAggregationFun to regenerate, say, ls-R (TeX-related file list)
  Just installing a few packages doesn't work.
  */
  texLiveAggregationFun = params:
    builderDefsPackage (import ../tools/typesetting/tex/texlive/aggregate.nix)
      ({inherit poppler perl makeWrapper;} // params);

  texDisser = callPackage ../tools/typesetting/tex/disser {};

  texLiveContext = builderDefsPackage (import ../tools/typesetting/tex/texlive/context.nix) {
    inherit texLive;
  };

  texLiveExtra = builderDefsPackage (import ../tools/typesetting/tex/texlive/extra.nix) {
    inherit texLive xz;
  };

  texLiveCMSuper = builderDefsPackage (import ../tools/typesetting/tex/texlive/cm-super.nix) {
    inherit texLive;
  };

  texLiveLatexXColor = builderDefsPackage (import ../tools/typesetting/tex/texlive/xcolor.nix) {
    inherit texLive;
  };

  texLivePGF = builderDefsPackage (import ../tools/typesetting/tex/texlive/pgf.nix) {
    inherit texLiveLatexXColor texLive;
  };

  texLiveBeamer = builderDefsPackage (import ../tools/typesetting/tex/texlive/beamer.nix) {
    inherit texLiveLatexXColor texLivePGF texLive;
  };

  texLiveModerncv = builderDefsPackage (import ../tools/typesetting/tex/texlive/moderncv.nix) {
    inherit texLive unzip;
  };

  texLiveModerntimeline = builderDefsPackage (import ../tools/typesetting/tex/texlive/moderntimeline.nix) {
    inherit texLive unzip;
  };

  thermald = callPackage ../tools/system/thermald { };

  thinkfan = callPackage ../tools/system/thinkfan { };

  vice = callPackage ../misc/emulators/vice {
    libX11 = xlibs.libX11;
    giflib = giflib_4_1;
  };

  viewnior = callPackage ../applications/graphics/viewnior { };

  vimrc = callPackage ../misc/vim-plugins/vimrc.nix { inherit writeText; };

  vimPlugins = recurseIntoAttrs (callPackage ../misc/vim-plugins { });

  vimprobable2 = callPackage ../applications/networking/browsers/vimprobable2 {
    webkit = webkitgtk2;
  };

  vimprobable2Wrapper = wrapFirefox
    { browser = vimprobable2; browserName = "vimprobable2"; desktopName = "Vimprobable2";
    };

  vimb = callPackage ../applications/networking/browsers/vimb {
    webkit = webkitgtk2;
  };

  vimbWrapper = wrapFirefox {
    browser = vimb;
    browserName = "vimb";
    desktopName = "Vimb";
  };

  VisualBoyAdvance = callPackage ../misc/emulators/VisualBoyAdvance { };

  # Wine cannot be built in 64-bit; use a 32-bit build instead.
  wineStable = callPackage_i686 ../misc/emulators/wine/stable.nix {
    bison = bison2;
  };

  wineUnstable = lowPrio (callPackage_i686 ../misc/emulators/wine/unstable.nix {
    bison = bison2;
  });

  wine = wineStable;

  winetricks = callPackage ../misc/emulators/wine/winetricks.nix {
    inherit (gnome2) zenity;
  };

  wxmupen64plus = callPackage ../misc/emulators/wxmupen64plus { };

  x2x = callPackage ../tools/X11/x2x { };

  xboxdrv = callPackage ../misc/drivers/xboxdrv { };

  xinput_calibrator = callPackage ../tools/X11/xinput_calibrator {
    inherit (xlibs) libXi inputproto;
  };

  xosd = callPackage ../misc/xosd { };

  xsane = callPackage ../applications/graphics/sane/xsane.nix {
    libpng = libpng12;
    saneBackends = saneBackends;
  };

  xwiimote = callPackage ../misc/drivers/xwiimote {
    bluez = pkgs.bluez5.override {
      enableWiimote = true;
    };
  };

  yafc = callPackage ../applications/networking/yafc { };

  yandex-disk = callPackage ../tools/filesystems/yandex-disk { };

  zdfmediathk = callPackage ../applications/video/zdfmediathk { };

  myEnvFun = import ../misc/my-env {
    inherit substituteAll pkgs;
    inherit (stdenv) mkDerivation;
  };

  # patoline requires a rather large ocaml compilation environment.
  # this is why it is build as an environment and not just a normal package.
  # remark : the emacs mode is also installed, but you have to adjust your load-path.
  PatolineEnv = pack: myEnvFun {
      name = "patoline";
      buildInputs = [ stdenv ncurses mesa freeglut libzip gcc
                                   pack.ocaml pack.findlib pack.camomile
                                   pack.dypgen pack.ocaml_sqlite3 pack.camlzip
                                   pack.lablgtk pack.camlimages pack.ocaml_cairo
                                   pack.lablgl pack.ocamlnet pack.cryptokit
                                   pack.ocaml_pcre pack.patoline
                                   ];
    # this is to circumvent the bug with libgcc_s.so.1 which is
    # not found when using thread
    extraCmds = ''
       LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:${gcc.gcc}/lib
       export LD_LIBRARY_PATH
    '';
  };

  patoline = PatolineEnv ocamlPackages_4_00_1;

  znc = callPackage ../applications/networking/znc { };

  zncModules = recurseIntoAttrs (
    callPackage ../applications/networking/znc/modules.nix { }
  );

  zsnes = callPackage_i686 ../misc/emulators/zsnes { };

  snes9x-gtk = callPackage ../misc/emulators/snes9x-gtk { };

  higan = callPackage ../misc/emulators/higan {
    profile = config.higan.profile or "performance";
    guiToolkit = config.higan.guiToolkit or "gtk";
  };

  misc = import ../misc/misc.nix { inherit pkgs stdenv; };

  bullet = callPackage ../development/libraries/bullet {};

  dart = callPackage ../development/interpreters/dart { };

  httrack = callPackage ../tools/backup/httrack { };

  mg = callPackage ../applications/editors/mg { };


  # Attributes for backward compatibility.
  adobeReader = adobe-reader;
  asciidocFull = asciidoc-full;  # added 2014-06-22
  lttngTools = lttng-tools;  # added 2014-07-31
  lttngUst = lttng-ust;  # added 2014-07-31
  jquery_ui = jquery-ui;  # added 2014-09-07
  youtubeDL = youtube-dl;  # added 2014-10-26
  rdiff_backup = rdiff-backup;  # added 2014-11-23

  opentsdb = callPackage ../tools/misc/opentsdb {};

  hbase = callPackage ../servers/hbase {};

}; in self; in pkgs
