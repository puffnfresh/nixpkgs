{
  bootstrapTools = builtins.fetchTarball {
    url = "https://brianmckenna.org/files/nix/windows/bootstrap-tools.tar.xz";
    sha256 = "1lhrhh7hxhz9rzf4gmbprzdvj4cz1zql80d0xb1nf0g9pizry8q1";
  };
}
