{pkgs ? import <nixpkgs> {} }:

pkgs.mkShell{
  buildInputs = with pkgs; [
    zig_0_12
    python3
  ];
}

