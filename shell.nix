let
  pkgs = import <nixpkgs> {};
in
pkgs.mkShell {
  buildInputs = [
    pkgs.elixir_1_13
    pkgs.inotify-tools
  ];
}
