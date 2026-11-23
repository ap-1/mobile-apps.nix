{
  description = "Nix builders for Android and iOS apps";

  inputs = {
    # TODO: https://github.com/NixOS/nixpkgs/pull/591229
    nixpkgs-xtool.url = "github:NixOS/nixpkgs/c3b998651c54ff8237b32d2e82055d372d76f140";
  };

  outputs =
    { self, nixpkgs-xtool }:
    {
      lib.mkLib = pkgs: import ./. { inherit pkgs nixpkgs-xtool; };

      checks.x86_64-linux =
        let
          pkgs = nixpkgs-xtool.legacyPackages.x86_64-linux;
          testapp = pkgs.callPackage ./examples/capacitor-testapp { mobile = self.lib.mkLib pkgs; };
        in
        {
          capacitor-testapp-ios = testapp.ios;
          capacitor-testapp-android = testapp.android;
        };
    };
}
