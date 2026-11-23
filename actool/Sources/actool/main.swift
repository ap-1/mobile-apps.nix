import AssetKit
import Foundation

let version = "0.1.0"

let valueFlags: Set<String> = [
    "--compile", "--output-format", "--export-dependency-info", "--output-partial-info-plist",
    "--minimum-deployment-target", "--platform", "--bundle-identifier", "--development-region",
    "--app-icon", "--alternate-app-icon", "--launch-image", "--accent-color", "--widget-background-color",
    "--target-device", "--ui-framework-family", "--include-language", "--enable-on-demand-resources",
    "--asset-pack-output-specifications", "--standalone-icon-behavior", "--optimization",
    "--lightweight-asset-runtime-mode", "--include-partial-info-plist-localizations",
    "--enable-incremental-distill", "--target-name", "--filter-for-thinning-device-configuration",
    "--filter-for-device-model", "--filter-for-device-os-version", "--sticker-pack-strings-file",
    "--sticker-pack-identifier-prefix", "--stickers-icon-role",
    "--generate-swift-asset-symbols", "--generate-objc-asset-symbols", "--generate-asset-symbol-index",
    "--generate-swift-asset-symbol-extensions", "--generate-asset-symbol-warnings",
    "--generate-asset-symbol-errors", "--generate-asset-symbol-framework-support",
    "--generate-asset-symbol-backwards-deployment-support",
]
let booleanFlags: Set<String> = [
    "--version", "--print-asset-tag-combinations", "--notices", "--warnings", "--compress-pngs",
    "--include-all-app-icons", "--skip-app-store-deployment", "--include-sticker-content",
]

struct Arguments {
    var catalogs: [URL] = []
    var values: [String: [String]] = [:]
    var flags: Set<String> = []

    init(_ arguments: ArraySlice<String>) throws {
        var iterator = arguments.makeIterator()
        while let argument = iterator.next() {
            if valueFlags.contains(argument) {
                guard let value = iterator.next() else { throw Failure("missing value for \(argument)") }
                values[argument, default: []].append(value)
            } else if booleanFlags.contains(argument) {
                flags.insert(argument)
            } else if argument.hasPrefix("--") {
                throw Failure("unknown option \(argument)")
            } else {
                catalogs.append(URL(fileURLWithPath: argument))
            }
        }
    }

    func value(_ flag: String) -> String? { values[flag]?.last }
}

struct Failure: Error, CustomStringConvertible {
    var description: String
    init(_ description: String) { self.description = description }
}

func directories(in url: URL) throws -> [URL] {
    try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey])
        .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
}

func dependencyInfo(inputs: [URL], outputs: [URL]) -> Data {
    var data = Data([0x00])
    data.append(contentsOf: Array("actool-\(version)".utf8) + [0])
    for input in inputs { data.append(contentsOf: [0x10] + Array(input.path.utf8) + [0]) }
    for output in outputs { data.append(contentsOf: [0x40] + Array(output.path.utf8) + [0]) }
    return data
}

func printResults(_ outputs: [URL], format: String?) throws {
    if format == "human-readable-text" {
        print("/* com.apple.actool.compilation-results */")
        outputs.forEach { print($0.path) }
        print()
    } else {
        try writePlist(["com.apple.actool.compilation-results": ["output-files": outputs.map(\.path)]], to: "/dev/stdout")
    }
}

func writePlist(_ plist: [String: Any], to path: String) throws {
    try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        .write(to: URL(fileURLWithPath: path))
}

func mergedCatalog(_ catalogs: [URL]) throws -> URL {
    if catalogs.count == 1 { return catalogs[0] }
    let merged = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathComponent("Merged.xcassets")
    try FileManager.default.createDirectory(at: merged, withIntermediateDirectories: true)
    try Data(#"{"info":{"author":"xcode","version":1}}"#.utf8)
        .write(to: merged.appendingPathComponent("Contents.json"))
    for catalog in catalogs {
        for child in try directories(in: catalog) {
            try FileManager.default.copyItem(at: child, to: merged.appendingPathComponent(child.lastPathComponent))
        }
    }
    return merged
}

func removeTree(_ url: URL) {
    let fileManager = FileManager.default
    try? fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
    for case let item as URL in fileManager.enumerator(at: url, includingPropertiesForKeys: nil) ?? .init() {
        try? fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: item.path)
    }
    try? fileManager.removeItem(at: url)
}

func run() async throws {
    let arguments = try Arguments(CommandLine.arguments.dropFirst())

    if arguments.flags.contains("--version") {
        try writePlist(["com.apple.actool.version": ["bundle-version": version, "short-bundle-version": version]], to: "/dev/stdout")
        return
    }

    if arguments.flags.contains("--print-asset-tag-combinations") {
        try writePlist(["com.apple.actool.asset-tag-combinations": [[String]]()], to: "/dev/stdout")
        return
    }

    guard let outputDirectory = arguments.value("--compile").map({ URL(fileURLWithPath: $0) }) else {
        throw Failure("--compile is required")
    }
    guard !arguments.catalogs.isEmpty else { throw Failure("no asset catalog given") }
    for catalog in arguments.catalogs where catalog.pathExtension != "xcassets" {
        throw Failure("\(catalog.path): only .xcassets catalogs are supported")
    }
    try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

    var outputs: [URL] = []

    let symbolFlags = ["--generate-swift-asset-symbols", "--generate-objc-asset-symbols", "--generate-asset-symbol-index"]
    if symbolFlags.contains(where: { arguments.value($0) != nil }) {
        if arguments.value("--generate-swift-asset-symbols") != nil,
            arguments.value("--generate-swift-asset-symbol-extensions") != "NO"
        {
            throw Failure("only --generate-swift-asset-symbol-extensions NO is supported")
        }
        if arguments.values["--generate-asset-symbol-framework-support"] != nil {
            throw Failure("--generate-asset-symbol-framework-support is not supported")
        }
        let assets = arguments.catalogs.flatMap(catalogAssets)
        let options = SymbolOptions(
            platform: arguments.value("--platform"),
            deploymentTarget: arguments.value("--minimum-deployment-target"),
            backwardsDeploymentSupport: arguments.value("--generate-asset-symbol-backwards-deployment-support"),
            targetDevices: arguments.values["--target-device"] ?? [],
            bundleID: arguments.value("--bundle-identifier") ?? ""
        )
        if let path = arguments.value("--generate-swift-asset-symbols") {
            try Data(swiftSymbols(assets, options: options).utf8).write(to: URL(fileURLWithPath: path))
            outputs.append(URL(fileURLWithPath: path))
        }
        if let path = arguments.value("--generate-objc-asset-symbols") {
            try Data(objcSymbols(assets, options: options).utf8).write(to: URL(fileURLWithPath: path))
            outputs.append(URL(fileURLWithPath: path))
        }
        if let path = arguments.value("--generate-asset-symbol-index") {
            try writePlist(symbolIndex(assets, options: options), to: path)
            outputs.append(URL(fileURLWithPath: path))
        }
    } else {
        let compiler = XCAssetCompiler(
            deploymentTarget: arguments.value("--minimum-deployment-target") ?? "16.0",
            svgRasterizer: RsvgConvertRasterizer(
                executablePath: ProcessInfo.processInfo.environment["RSVG_CONVERT"] ?? "/usr/bin/env"
            )
        )
        let catalog = try mergedCatalog(arguments.catalogs)
        defer { if catalog != arguments.catalogs[0] { removeTree(catalog.deletingLastPathComponent()) } }
        let result = try await compiler.compile(catalog: catalog)

        let car = outputDirectory.appendingPathComponent("Assets.car")
        try result.carData.write(to: car)
        outputs.append(car)

        var partial: [String: Any] = [:]
        if let icon = result.appIconBundle, arguments.value("--app-icon") == icon.primaryIconName {
            partial.merge(icon.infoPlistAdditions) { $1 }
            for file in icon.looseFiles {
                let url = outputDirectory.appendingPathComponent(file.name)
                try file.data.write(to: url)
                outputs.append(url)
            }
        }
        if let path = arguments.value("--output-partial-info-plist") {
            try writePlist(partial, to: path)
            outputs.append(URL(fileURLWithPath: path))
        }
        if let path = arguments.value("--export-dependency-info") {
            let sorted = outputs.sorted { codePointOrder($0.path, $1.path) }
            try dependencyInfo(inputs: arguments.catalogs, outputs: sorted).write(to: URL(fileURLWithPath: path))
        }
    }

    try printResults(outputs.sorted { codePointOrder($0.path, $1.path) }, format: arguments.value("--output-format"))
}

do {
    try await run()
} catch {
    FileHandle.standardError.write(Data("actool: error: \(error)\n".utf8))
    exit(1)
}
