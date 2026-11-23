{
  rustPlatform,
  fetchFromGitHub,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "rcodesign-ffi";
  version = "0.2.0-unstable-2026-11-22";

  # TODO: https://github.com/xtool-org/swift-rcodesign/pull/2
  src = fetchFromGitHub {
    owner = "ap-1";
    repo = "swift-rcodesign";
    rev = "a9cdc9f86e11c9ed2c2fef971d217d7d84696b63";
    hash = "sha256-AdW0nCOEh5T/0v2YEKUynLGGQBoB0Q7vWGV+6r/dBes=";
  };

  cargoHash = "sha256-/Rz0y/XB0MimII0Vh6DwEF0uDsTXph2bt89p2PtHAoU=";

  postInstall = ''
    install -Dm644 include/rcodesign.h "$out/include/rcodesign.h"
    mkdir -p "$out/lib/pkgconfig"
    cat > "$out/lib/pkgconfig/rcodesign_ffi.pc" <<EOF
    Name: rcodesign_ffi
    Description: C bindings to apple-codesign
    Version: ${finalAttrs.version}
    Cflags: -I$out/include
    Libs: -L$out/lib -lrcodesign_ffi
    EOF
  '';
})
