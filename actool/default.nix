{
  lib,
  stdenv,
  swift,
  swiftpm,
  fetchSwiftPMDeps,
  makeWrapper,
  librsvg,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "actool";
  version = "0.1.0";

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./Package.swift
      ./Package.resolved
      ./Sources
    ];
  };

  nativeBuildInputs = [
    swift
    swiftpm
    makeWrapper
  ];

  swiftpmDeps = fetchSwiftPMDeps {
    inherit (finalAttrs) pname version src;
    hash = "sha256-AGPF0hhWB2xtt1eYF0hyRkbdt3x4gg7nXTkLH55rTcg=";
  };

  # TODO: https://github.com/xtool-org/AssetKit/pull/2
  postPatch = ''
    rm Packages
    cp -rL --no-preserve=mode "$swiftpmDeps/Packages" Packages
    patch -d Packages/AssetKit -p1 < ${./single-size-app-icons.patch}
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 "$(swiftpmBinPath)/actool" "$out/bin/actool"
    wrapProgram "$out/bin/actool" --set RSVG_CONVERT ${lib.getExe' librsvg "rsvg-convert"}
    runHook postInstall
  '';

  meta.mainProgram = "actool";
})
