{ mkDerivation, alsa-core, alsa-mixer, dbus, filepath, hinotify, HTTP
, libmpd, libXrandr, mtl, parsec, regex-compat, stm, time
, timezone-olson, timezone-series, utf8-string, wirelesstools, X11
, X11-xft
}:

mkDerivation {
  pname = "xmobar";
  version = "0.20.1";
  src = ./.;
  isLibrary = true;
  isExecutable = true;
  buildDepends = [
    alsa-core alsa-mixer dbus filepath hinotify HTTP libmpd mtl parsec
    regex-compat stm time timezone-olson timezone-series utf8-string X11
    X11-xft
  ];
  extraLibraries = [ libXrandr wirelesstools ];
  configureFlags = [ "-fall_extensions" ];
  license = null;
}
