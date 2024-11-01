{ lib
, stdenv
, windows
, autoreconfHook
, mingw_w64_headers
}:

stdenv.mkDerivation {
  pname = "mingw-w64";
  inherit (mingw_w64_headers) version src meta;

  outputs = [ "out" "dev" ];

  configureFlags = lib.optionals stdenv.targetPlatform.isMinGW [
    "--enable-idl"
    "--enable-secure-api"
  ] ++ lib.optionals stdenv.targetPlatform.isCygwin [
    "--enable-w32api"
  ] ++ lib.optionals (stdenv.targetPlatform.libc == "ucrt") [
    "--with-default-msvcrt=ucrt"
  ];

  postInstall = lib.optionalString stdenv.targetPlatform.isCygwin ''
    cd $out/lib
    ln -fs w32api/libkernel32.a .
    ln -fs w32api/libuser32.a .
    ln -fs w32api/libadvapi32.a .
    ln -fs w32api/libshell32.a .
    ln -fs w32api/libgdi32.a .
    ln -fs w32api/libcomdlg32.a .
    ln -fs w32api/libntdll.a .
    ln -fs w32api/libnetapi32.a .
    ln -fs w32api/libpsapi.a .
    ln -fs w32api/libuserenv.a .
    ln -fs w32api/libnetapi32.a .
    ln -fs w32api/libdbghelp.a .
  '';

  enableParallelBuilding = true;

  nativeBuildInputs = [ autoreconfHook ];
  buildInputs = [ windows.mingw_w64_headers ];
  hardeningDisable = [ "stackprotector" "fortify" ];
}
