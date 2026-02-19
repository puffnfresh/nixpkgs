{
  bootstrapTools = builtins.fetchTarball {
    url = "https://brianmckenna.org/files/nix/windows/bootstrap-tools.tar.xz";
    sha256 = "1zv529cqsfawq8zlcmyi3zd1dgm6dawqvb1nbz876z4y71jmgd5q";
  };
}
