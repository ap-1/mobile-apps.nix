{ pkgs, nixpkgs-xtool }:

let
  xtoolPkgs = import nixpkgs-xtool {
    inherit (pkgs.stdenv.hostPlatform) system;
    config.allowUnfree = true;
  };
  actool = xtoolPkgs.callPackage ./actool { };
  xtool = xtoolPkgs.callPackage ./xtool { };
  xtoolBuildHook = xtoolPkgs.xtoolBuildHook.override {
    inherit xtool;
    swift = xtoolPkgs.swift.overrideAttrs (old: {
      # swift-build finds actool in usr/bin and libclang through ToolchainInfo.plist
      buildCommand = old.buildCommand + ''
        mkdir -p "$out/usr/bin"
        ln -s ${lib.getExe actool} "$out/usr/bin/actool"
        cp ${./xtool/ToolchainInfo.plist} "$out/ToolchainInfo.plist"
      '';
    });
  };
  inherit (pkgs) lib;
in
{
  inherit
    xtoolPkgs
    actool
    xtool
    xtoolBuildHook
    ;

  androidSdk = args: import ./android-sdk.nix ({ inherit pkgs; } // args);

  capacitor = {
    buildAndroidApp = pkgs.callPackage ./capacitor/android.nix { };
    buildIosApp = import ./capacitor/ios.nix { inherit pkgs xtoolPkgs xtoolBuildHook; };
  };
}
