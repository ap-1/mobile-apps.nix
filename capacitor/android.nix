{
  pkgs,
  stdenv,
  callPackage,
  gradle_8,
}:

{
  src,
  pname,
  version,
  app,
  web,
  nodeModules,
  gradleDeps,
  gradle ? gradle_8,
  sdk ? import ../android-sdk.nix { inherit pkgs; },
}:

let
  capacitor = callPackage ./. { } {
    inherit app web nodeModules;
    platform = "android";
  };
in
stdenv.mkDerivation (finalAttrs: {
  inherit pname version src;

  nativeBuildInputs = capacitor.nativeBuildInputs ++ [ gradle ];
  inherit (capacitor) buildInputs;

  mitmCache = gradle.fetchDeps {
    pkg = finalAttrs.finalPackage;
    data = gradleDeps;
    # the Capacitor CLI reads the user's passwd entry
    bwrapFlags = ''--ro-bind "$PWD" "$PWD" --ro-bind /etc/passwd /etc/passwd --ro-bind /etc/group /etc/group'';
  };
  __darwinAllowLocalNetworking = true;

  env.ANDROID_HOME = sdk.home;
  gradleFlags = [
    "-Pandroid.aapt2FromMavenOverride=${sdk.buildTools}/aapt2"
    "-Porg.gradle.java.installations.paths=${sdk.jdk.home}"
    # lint's Maven indexes are unversioned and can't be pinned in deps.json
    "-x"
    "lintVitalRelease"
  ];
  gradleBuildTask = "assembleRelease";
  # nixDownloadDeps fails resolving Android's test classpaths
  gradleUpdateTask = "assembleRelease";

  configurePhase = ''
    runHook preConfigure
    export ANDROID_USER_HOME="$TMPDIR/android"
    ${capacitor.prepare}
    runHook postConfigure
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp app/build/outputs/apk/release/*.apk "$out/"
    runHook postInstall
  '';
})
