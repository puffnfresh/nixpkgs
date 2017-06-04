{ stdenv, fetchFromGitHub, munge, lua, libcap, perl, ncurses }:

stdenv.mkDerivation rec {
  name = "diod-${version}";
  version = "d29c10e5";

  src = fetchFromGitHub {
    # rev = "d29c10e5cef230392118cd608a9e86a5da0b8f95";
    rev = "afcd925de2503f92eca4817e6387e661aaf878e7";
    owner = "chaos";
    repo = "diod";
    # sha256 = "0vccyjrjkqdpbyagg0m3avm80dkbl0bczw3r7kyhyri8in5riqgv";
    sha256 = "00m4mxnnwzrk0vlw4zip29g6didiyb625pakphqykr8v875zm5b7";
  };

  patches = [ ./0001-Skip-getaddrinfo-for-AF_UNIX.patch ];

  # preConfigure = "./autogen.sh";
  # prePatch = ''
  #   sed -ri 's/st_([amc])tim\./st_\1timespec./g' libnpclient/stat.c
  #   sed -ri 's/st_([amc])tim\./st_\1timespec./g' diod/ops.c
  #   sed -i 's/O_DIRECT)/0)/g' diod/ops.c
  #   sed -i 's/TCP_KEEPIDLE/TCP_KEEPALIVE/g' libdiod/diod_sock.c
  # '';
  buildInputs = [ munge lua perl ncurses ];
  # makeFlags = [ "CFLAGS+=-D__FreeBSD__" ];

  meta = {
    description = "An I/O forwarding server that implements a variant of the 9P protocol";
    maintainers = [ stdenv.lib.maintainers.rickynils ];
    platforms = stdenv.lib.platforms.unix;
  };
}
