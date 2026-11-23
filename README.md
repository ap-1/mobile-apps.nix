# mobile-apps.nix

Nix builders for Android and iOS apps.

```nix
{
  inputs.mobile-apps.url = "github:ap-1/mobile-apps.nix";

  outputs =
    { nixpkgs, mobile-apps, ... }:
    let
      mobile = mobile-apps.lib.mkLib nixpkgs.legacyPackages.x86_64-linux;
    in
    {
      packages.x86_64-linux = {
        ios = mobile.capacitor.buildIosApp { ... };
        android = mobile.capacitor.buildAndroidApp { ... };
      };
    };
}
```

[`examples/capacitor-testapp/default.nix`](examples/capacitor-testapp/default.nix) builds Ionic's Capacitor test app for iOS and Android.

## Acknowledgements

- [Kabir Oberai](https://github.com/kabiroberai) for xtool
- [Randy Eckenrode](https://github.com/reckenrode) for maintaining Swift in Nixpkgs
