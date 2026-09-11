{ stdenv, cmake, qtbase, qtsvg, wrapQtAppsHook, version }:
stdenv.mkDerivation {
  pname = "nixdatifier-tray";
  inherit version;
  src = ./.;
  nativeBuildInputs = [ cmake wrapQtAppsHook ];
  buildInputs = [ qtbase qtsvg ];
}
