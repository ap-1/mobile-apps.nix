{
  lib,
  callPackage,
  darwin,
  fetchFromGitHub,
  fetchSwiftPMDeps,
  jq,
  llvmPackages,
  ncurses,
  sqlite,
  xtool,
}:

let
  rcodesign = callPackage ./rcodesign.nix { };

  # TODO: https://github.com/xtool-org/swift-rcodesign/pull/2
  useRcodesignFork = ''
    substituteInPlace Package.swift --replace-fail \
      '.package(url: "https://github.com/xtool-org/swift-rcodesign", .upToNextMinor(from: "0.2.0"))' \
      '.package(url: "https://github.com/ap-1/swift-rcodesign", revision: "${rcodesign.src.rev}")'
    jq --arg rev ${rcodesign.src.rev} '
      (.pins[] | select(.identity == "swift-rcodesign"))
        |= (.location = "https://github.com/ap-1/swift-rcodesign" | .state = { revision: $rev })
    ' Package.resolved > Package.resolved.new
    mv Package.resolved.new Package.resolved
  '';
in
xtool.overrideAttrs (
  finalAttrs: old: {
    version = "2.0.0-beta.1-unstable-2026-11-16";

    src = fetchFromGitHub {
      owner = "xtool-org";
      repo = "xtool";
      rev = "73dc5f1eb83daf3a218186486a6bbcb644cda1a7";
      hash = "sha256-gaPDGntCMzc4pj1sTaJDovfjevECHIREUf0cygokIuY=";
    };

    patches = [
      ./sdk-version-overrides.patch
      # TODO: https://github.com/xtool-org/xtool/pull/459
      ./toolchain-prefix-layout.patch
      # TODO: https://github.com/xtool-org/xtool/pull/461
      ./emulate-touch.patch
      # TODO: https://github.com/xtool-org/xtool/pull/465
      ./swift-library-path.patch
      # TODO: https://github.com/xtool-org/xtool/pull/466
      ./prepare-packages.patch
    ];
    postPatch = useRcodesignFork;

    swiftpmDeps = fetchSwiftPMDeps {
      inherit (finalAttrs) pname version src;
      nativeBuildInputs = [ jq ];
      postPatch = useRcodesignFork;
      hash = "sha256-myt0ZAeE8uK69Oq+RY1g641GGlb7Lrj6D/OV79T+MKc=";
    };

    nativeBuildInputs = old.nativeBuildInputs ++ [ jq ];
    buildInputs = old.buildInputs ++ [
      ncurses
      sqlite
      rcodesign
    ];

    # libgcc's unwinder crashes when swift-testing backtraces errors thrown from async code
    preCheck = ''
      export SWT_SWIFT_ERROR_BACKTRACING_ENABLED=0
    '';

    # SwiftBuild loads its specs from these bundles next to the executable
    postInstall = ''
      cp -r "$(swiftpmBinPath)"/*.bundle "$out/bin/"
    ''
    + old.postInstall;

    # the emulated strip and bitcode_strip run llvm-objcopy
    makeWrapperArgs = old.makeWrapperArgs ++ [
      "--suffix"
      "PATH"
      ":"
      (lib.makeBinPath [ llvmPackages.llvm ])
    ];

    passthru = old.passthru // {
      # nixpkgs copies the host's clang headers into the SDK because 1.x compiled with the SDK's,
      # but 2.0 points the compiler at the host's directly
      sdk = old.passthru.sdk.overrideAttrs {
        buildCommand = ''
          xtool sdk build ${darwin.xcode_27_1} "$TMPDIR"
          mv "$TMPDIR/darwin.xtoolsdk" "$out"
        '';
      };
    };
  }
)
