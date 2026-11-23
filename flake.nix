{
  description = "Nix builders for Android and iOS apps";

  inputs = {
    # TODO: https://github.com/NixOS/nixpkgs/pull/591229
    nixpkgs-xtool.url = "github:NixOS/nixpkgs/c3b998651c54ff8237b32d2e82055d372d76f140";
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs-xtool";
    };
  };

  outputs =
    {
      self,
      nixpkgs-xtool,
      treefmt-nix,
    }:
    let
      pkgs = nixpkgs-xtool.legacyPackages.x86_64-linux;
      mobile = self.lib.mkLib pkgs;
      testapp = pkgs.callPackage ./examples/capacitor-testapp { inherit mobile; };

      treefmt = treefmt-nix.lib.evalModule pkgs {
        programs.nixfmt.enable = true;
        programs.mdformat.enable = true;
        programs.swift-format.enable = true;
        settings.global.excludes = [ "examples/capacitor-testapp/ios/**" ];
      };
    in
    {
      lib.mkLib = pkgs: import ./. { inherit pkgs nixpkgs-xtool; };

      formatter.x86_64-linux = treefmt.config.build.wrapper;

      checks.x86_64-linux = {
        formatting = treefmt.config.build.check self;
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
