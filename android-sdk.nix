{
  pkgs,
  platformVersion ? "36",
  buildToolsVersion ? "35.0.0",
  emulator ? false,
}:

let
  androidPkgs = import pkgs.path {
    inherit (pkgs.stdenv.hostPlatform) system;
    config = {
      allowUnfree = true;
      android_sdk.accept_license = true;
    };
  };

  sdk =
    (androidPkgs.androidenv.composeAndroidPackages {
      platformVersions = [ platformVersion ];
      buildToolsVersions = [ buildToolsVersion ];
      includeEmulator = emulator;
      includeSystemImages = emulator;
      systemImageTypes = [ "google_apis_playstore" ];
      abiVersions = [
        "arm64-v8a"
        "x86_64"
      ];
      cmakeVersions = [ ];
    }).androidsdk;

  home = "${sdk}/libexec/android-sdk";
in
{
  inherit sdk home;
  jdk = pkgs.jdk21;
  buildTools = "${home}/build-tools/${buildToolsVersion}";
}
