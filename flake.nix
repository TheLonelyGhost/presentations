{
  description = "An archive of public presentations given by David Alexander";
  inputs.nixpkgs.url = "flake:nixpkgs";
  inputs.flake-utils.url = "flake:flake-utils";

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };
      in
      {
        devShell = pkgs.mkShell {
          nativeBuildInputs = [
            pkgs.bashInteractive
            pkgs.envsubst
            pkgs.pandoc
            pkgs.nodejs
            pkgs.nodePackages.yarn
          ];
          buildInputs = [
          ];
        };
      });
}
