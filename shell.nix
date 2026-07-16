{ pkgs ? import <nixpkgs> { } }:
let
  # Pinned to match Cloudflare Pages' build environment exactly
  # (hugo v0.118.2-extended, official upstream binary, not nixpkgs' build).
  hugo-pinned = pkgs.runCommand "hugo-0.118.2" { } ''
    mkdir -p $out/bin
    tar -xzf ${pkgs.fetchurl {
      url = "https://github.com/gohugoio/hugo/releases/download/v0.118.2/hugo_extended_0.118.2_linux-amd64.tar.gz";
      sha256 = "sha256-vHJQKBaSpAxJl6bHH5Oylj3jA4yKvzbmHYy1KGZMEF0=";
    }} -O hugo > $out/bin/hugo
    chmod +x $out/bin/hugo
  '';
in
pkgs.mkShell {
  nativeBuildInputs = [ hugo-pinned pkgs.git ];
}
