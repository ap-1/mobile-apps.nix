# capacitor-testapp

Builds [ionic-team/capacitor-testapp](https://github.com/ionic-team/capacitor-testapp) for iOS and Android.

## Updating

After changing `rev` in `default.nix`, regenerate the files below from a checkout of the new revision.

### `ios/`

xtool can't build upstream's CocoaPods project, so generate `ios/` with Capacitor's Swift Package Manager template:

```sh
npm ci --ignore-scripts
npm run build
rm -r ios
npx cap add ios --packagemanager SPM
```

Storyboards are compiled by Apple's `ibtool`, which only runs on macOS. After replacing `ios/` here with the generated one, remove `Base.lproj/LaunchScreen.storyboard` and its references in `App.xcodeproj/project.pbxproj`, and then replace `UILaunchStoryboardName` in `Info.plist` with

```xml
<key>UILaunchScreen</key>
<dict>
	<key>UIImageName</key>
	<string>Splash</string>
	<key>UIImageRespectsSafeAreaInsets</key>
	<false/>
</dict>
```

### `Package.resolved`

From the generated `ios/App`:

```sh
cd "$(xtool dev prepare-packages)"
swift package resolve
```

Copy the resulting `Package.resolved` to `ios/App/App.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/`.

### `deps.json`

From the root of this repository:

```sh
$(nix build --no-link --print-out-paths .#checks.x86_64-linux.capacitor-testapp-android.mitmCache.updateScript)
```
