{
  lib,
  fetchFromGitHub,
  fetchNpmDeps,
  buildNpmPackage,
  runCommand,
  gradle_9,
  mobile,
}:

let
  pname = "capacitor-testapp";
  version = "0-unstable-2026-10-27";

  upstream = fetchFromGitHub {
    owner = "ionic-team";
    repo = "capacitor-testapp";
    rev = "b3299f201782864c73df9cff0edf92a64d29d1fc";
    hash = "sha256-ZHcVaFc8Lxipq7aDfK8GqRYTplnoj4s0GIeCphkYzFw=";
  };

  # xtool can't build upstream's CocoaPods project, so its ios/ is replaced with this one
  src = runCommand "${pname}-src" { } ''
    cp -r ${upstream} $out
    chmod -R u+w $out
    rm -r $out/ios
    cp -r ${./ios} $out/ios
  '';

  npmDeps = fetchNpmDeps {
    name = "${pname}-npm-deps";
    inherit src;
    hash = "sha256-3jTRUGJFnT/KTt2H3RFk28rnhpopJDhpfyMC/dupzBU=";
  };

  nodeModules = {
    install = ''
      export npm_config_cache="$TMPDIR/npm-cache" npm_config_offline=true npm_config_progress=false
      cp -r ${npmDeps} "$npm_config_cache"
      chmod -R u+w "$npm_config_cache"
      npm ci --ignore-scripts
      patchShebangs node_modules
    '';
  };

  web = buildNpmPackage {
    pname = "${pname}-web";
    inherit version src npmDeps;
    installPhase = ''
      runHook preInstall
      cp -r dist $out
      runHook postInstall
    '';
  };

  args = {
    inherit
      pname
      version
      src
      web
      nodeModules
      ;
    app = ".";
  };
in
{
  ios = mobile.capacitor.buildIosApp (
    args
    // {
      swiftpmDepsHash = "sha256-FA/hfSaPSc7LeNqh9aFi1EwFHuHbo2xaGVlwdDqL6I8=";
    }
  );

  android = mobile.capacitor.buildAndroidApp (
    args
    // {
      gradle = gradle_9;
      sdk = mobile.androidSdk {
        platformVersion = "37";
        buildToolsVersion = "36.0.0";
      };
      gradleDeps = ./deps.json;
    }
  );
}
