// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "actool",
    platforms: [.macOS(.v13)],
    dependencies: [
        // TODO: https://github.com/xtool-org/AssetKit/pull/8
        .package(url: "https://github.com/ap-1/AssetKit", revision: "772d47c285c5acbe6faa62a6a543209628fb1ece"),
    ],
    targets: [
        .executableTarget(
            name: "actool",
            dependencies: [.product(name: "AssetKit", package: "AssetKit")]
        ),
    ]
)
