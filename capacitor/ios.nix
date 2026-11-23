{
  pkgs,
  xtoolPkgs,
  xtoolBuildHook,
}:

{
  src,
  pname,
  version,
  app,
  web,
  nodeModules,
  swiftpmDepsHash,
}:

let
  capacitor = pkgs.callPackage ./. { } {
    inherit app web nodeModules;
    platform = "ios";
  };
  project = "${app}/ios/App";
  resolved = "App.xcodeproj/project.xcworkspace/xcshareddata/swiftpm";
in
xtoolPkgs.stdenv.mkDerivation (finalAttrs: {
  inherit pname version src;

  postUnpack = ''
    (
      cd "$sourceRoot"
      ${capacitor.prepare}
    )
    sourceRoot="$sourceRoot/${project}"
  '';

  # fetchSwiftPMDeps usually goes in swiftpmDeps, which swiftpmUnpackHook unpacks into sourceRoot,
  # but here sourceRoot is an Xcode project with no Package.swift
  projectSwiftpmDeps = xtoolPkgs.fetchSwiftPMDeps {
    inherit (finalAttrs) pname version src;
    postUnpack = ''sourceRoot="$sourceRoot/${project}/${resolved}"'';
    hash = swiftpmDepsHash;
  };

  nativeBuildInputs = capacitor.nativeBuildInputs ++ [
    xtoolBuildHook
    xtoolPkgs.swiftpm
  ];
  inherit (capacitor) buildInputs;

  preBuild = ''
    # swift-build treats environment variables as build settings
    unset CC LD AR

    # unpack the project's dependencies into the package xtool generates for them
    packageDir=$(xtool dev prepare-packages)
    swiftpmDeps=$projectSwiftpmDeps sourceRoot="''${packageDir#"$NIX_BUILD_TOP/"}" swiftpmUnpackDeps
  '';

  # skips signing
  xtoolBuildFlags = [
    "--triple"
    "arm64-apple-ios-simulator"
  ];
})
