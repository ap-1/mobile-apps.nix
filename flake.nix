{
  description = "Nix builders for Android and iOS apps";

  inputs = {
    # TODO: https://github.com/NixOS/nixpkgs/pull/591229
    nixpkgs-xtool.url = "github:NixOS/nixpkgs/c3b998651c54ff8237b32d2e82055d372d76f140";
  };

  outputs =
    { self, nixpkgs-xtool }:
    let
      pkgs = nixpkgs-xtool.legacyPackages.x86_64-linux;
      mobile = self.lib.mkLib pkgs;
      testapp = pkgs.callPackage ./examples/capacitor-testapp { inherit mobile; };
    in
    {
      lib.mkLib = pkgs: import ./. { inherit pkgs nixpkgs-xtool; };

      checks.x86_64-linux = {
        capacitor-testapp-ios = testapp.ios;
        capacitor-testapp-android = testapp.android;
      };

      # mkShell's CC, LD and AR would be read by swift-build as build settings
      devShells.x86_64-linux.default = pkgs.mkShellNoCC {
        packages = [
          mobile.xtool
          pkgs.swift
          pkgs.swiftpm
          pkgs.binutils-unwrapped
          pkgs.nodejs
        ];
      };
    };
}
