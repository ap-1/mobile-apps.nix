import Foundation

enum AssetKind {
    case color, image

    var suffix: String { self == .color ? "Color" : "Image" }
    var noun: String { self == .color ? "color" : "image" }
    var resourceType: String { self == .color ? "ColorResource" : "ImageResource" }
    var objcPrefix: String { self == .color ? "ACColorName" : "ACImageName" }
}

struct CatalogAsset {
    var kind: AssetKind
    var name: String
    var namespaces: [String]
    var catalog: URL
    var relativePath: String
    var idioms: [String]
}

enum SymbolFormat {
    case modern, backwardsDeployment, empty
}

struct SymbolOptions {
    var format: SymbolFormat
    var targetDevices: [String]
    var includesImages: Bool
    var bundleID: String

    init(
        platform: String?, deploymentTarget: String?, backwardsDeploymentSupport: String?, targetDevices: [String],
        bundleID: String
    ) {
        let cutoffs = [
            "iphoneos": 17, "iphonesimulator": 17, "appletvos": 17, "appletvsimulator": 17,
            "macosx": 14, "watchos": 10, "watchsimulator": 10,
        ]
        let belowCutoff: Bool
        if let deploymentTarget {
            let major = Int(deploymentTarget.split(separator: ".").first ?? "") ?? 0
            belowCutoff = cutoffs[platform ?? ""].map { major < $0 } ?? false
        } else {
            belowCutoff = true
        }
        switch backwardsDeploymentSupport {
        case "YES": format = .backwardsDeployment
        case "NO": format = belowCutoff ? .empty : .modern
        default: format = belowCutoff ? .backwardsDeployment : .modern
        }
        self.targetDevices = targetDevices
        includesImages = deploymentTarget != nil
        self.bundleID = bundleID
    }

    func appliesToAll(_ asset: CatalogAsset) -> Bool {
        targetDevices.allSatisfy { device in asset.idioms.contains { $0 == "universal" || $0 == device } }
    }

    func appliesToAny(_ asset: CatalogAsset) -> Bool {
        targetDevices.isEmpty
            || targetDevices.contains { device in asset.idioms.contains { $0 == "universal" || $0 == device } }
    }
}

func codePointOrder(_ a: String, _ b: String) -> Bool {
    a.unicodeScalars.map(\.value).lexicographicallyPrecedes(b.unicodeScalars.map(\.value))
}

func contents(of folder: URL) -> [String: Any] {
    guard
        let data = try? Data(contentsOf: folder.appendingPathComponent("Contents.json")),
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else { return [:] }
    return json
}

func catalogAssets(_ catalog: URL) -> [CatalogAsset] {
    var assets: [CatalogAsset] = []
    func walk(_ folder: URL, relativePath: String, namespaces: [String]) {
        let children =
            ((try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? [])
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .sorted { codePointOrder($0.lastPathComponent, $1.lastPathComponent) }
        for child in children {
            let name = child.deletingPathExtension().lastPathComponent
            let path = relativePath + "/" + child.lastPathComponent
            let (kind, list, key): (AssetKind, String, String)
            switch child.pathExtension {
            case "colorset": (kind, list, key) = (.color, "colors", "color")
            case "imageset": (kind, list, key) = (.image, "images", "filename")
            case "":
                let namespace =
                    (contents(of: child)["properties"] as? [String: Any])?["provides-namespace"] as? Bool ?? false
                walk(child, relativePath: path, namespaces: namespace ? namespaces + [name] : namespaces)
                continue
            default: continue
            }
            let entries = contents(of: child)[list] as? [[String: Any]] ?? []
            guard entries.contains(where: { $0[key] != nil }) else { continue }
            assets.append(
                CatalogAsset(
                    kind: kind, name: name, namespaces: namespaces, catalog: catalog, relativePath: path,
                    idioms: entries.compactMap { $0["idiom"] as? String }
                )
            )
        }
    }
    walk(catalog, relativePath: ".", namespaces: [])
    return assets
}

func words(_ name: String) -> [String] {
    name.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).flatMap { run -> [String] in
        let characters = Array(run)
        var words: [String] = []
        var start = 0
        for i in characters.indices.dropFirst() {
            let (previous, current) = (characters[i - 1], characters[i])
            let nextIsLowercase = i + 1 < characters.count && characters[i + 1].isLowercase
            if (previous.isLowercase && current.isUppercase)
                || (previous.isUppercase && current.isUppercase && nextIsLowercase)
                || (previous.isLetter && current.isNumber) || (previous.isNumber && current.isLetter)
            {
                words.append(String(characters[start..<i]))
                start = i
            }
        }
        return words + [String(characters[start...])]
    }
}

func capitalized(_ word: String) -> String {
    (word.first?.uppercased() ?? "") + word.dropFirst()
}

func swiftName(_ name: String, kind: AssetKind) -> String {
    var words = words(name)
    if words.count > 1, words.last?.lowercased() == kind.suffix.lowercased() { words.removeLast() }
    let joined =
        words.contains(where: { $0.contains(where: \.isLowercase) })
        ? (words.first?.lowercased() ?? "") + words.dropFirst().map(capitalized).joined()
        : words.joined(separator: "_")
    return joined.first?.isNumber ?? false ? "_" + joined : joined
}

func objcName(_ name: String) -> String {
    String(words(name).map(capitalized).joined().unicodeScalars.filter(\.isASCII).map(Character.init))
}

let swiftKeywords: Set<String> = [
    "Any", "Self", "as", "associatedtype", "break", "case", "catch", "class", "continue", "default", "defer",
    "deinit", "do", "else", "enum", "extension", "fallthrough", "false", "fileprivate", "for", "func", "guard",
    "if", "import", "in", "init", "inout", "internal", "is", "let", "nil", "operator", "precedencegroup",
    "private", "protocol", "public", "repeat", "rethrows", "return", "self", "static", "struct", "subscript",
    "super", "switch", "throw", "throws", "true", "try", "typealias", "var", "where", "while",
]

func escaped(_ identifier: String) -> String {
    swiftKeywords.contains(identifier) ? "`\(identifier)`" : identifier
}

func literal(_ name: String) -> String {
    name.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
}

func fullName(_ asset: CatalogAsset) -> String {
    literal((asset.namespaces + [asset.name]).joined(separator: "/"))
}

func swiftScope(_ assets: [CatalogAsset], depth: Int, kind: AssetKind, type: String, indent: String) -> String {
    let here = assets.filter { $0.namespaces.count == depth }
    let namespaces = Set(assets.filter { $0.namespaces.count > depth }.map { $0.namespaces[depth] })
    let entries = (here.map { ($0.name, Optional($0)) } + namespaces.map { ($0, nil) })
        .sorted { codePointOrder($0.0, $1.0) }
    var taken: Set<String> = []
    var items: [String] = []
    for (name, asset) in entries {
        if let asset {
            let symbol = swiftName(asset.name, kind: kind)
            guard taken.insert(symbol).inserted else {
                items.append(
                    "\(indent)#warning(\"The \\\"\(fullName(asset))\\\" \(kind.noun) asset name resolves to the symbol \\\"\(symbol)\\\" which already exists. Try renaming the asset.\")"
                )
                continue
            }
            items.append(
                """
                \(indent)/// The "\(fullName(asset))" asset catalog \(kind.noun) resource.
                \(indent)static let \(escaped(symbol)) = \(type)(name: "\(fullName(asset))", bundle: resourceBundle)
                """
            )
        } else {
            let inner = assets.filter { $0.namespaces.count > depth && $0.namespaces[depth] == name }
            let path = literal((inner[0].namespaces[...depth]).joined(separator: "/"))
            items.append(
                """
                \(indent)/// The "\(path)" asset catalog resource namespace.
                \(indent)enum \(escaped(words(name).map(capitalized).joined())) {
                \(swiftScope(inner, depth: depth + 1, kind: kind, type: type, indent: indent + "    "))
                \(indent)}
                """
            )
        }
    }
    return items.map { "\n\($0)\n" }.joined()
}

func swiftSymbols(_ assets: [CatalogAsset], options: SymbolOptions) -> String {
    let modern = options.format == .modern
    guard options.format != .empty else { return "" }
    var out = "import Foundation\n"
    if !modern {
        out += """
            #if canImport(AppKit)
            import AppKit
            #endif
            #if canImport(UIKit)
            import UIKit
            #endif
            #if canImport(SwiftUI)
            import SwiftUI
            #endif

            """
    }
    out += """
        #if canImport(DeveloperToolsSupport)
        import DeveloperToolsSupport
        #endif

        #if SWIFT_PACKAGE
        private let resourceBundle = Foundation.Bundle.module
        #else
        private class ResourceBundleClass {}
        private let resourceBundle = Foundation.Bundle(for: ResourceBundleClass.self)
        #endif

        """
    for kind in [AssetKind.color, .image] {
        let type = (modern ? "DeveloperToolsSupport." : "") + kind.resourceType
        let availability =
            modern
            ? "iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *"
            : kind == .color ? "iOS 11.0, macOS 10.13, tvOS 11.0, *" : "iOS 11.0, macOS 10.7, tvOS 11.0, *"
        let included = assets.filter {
            $0.kind == kind && (kind == .color || options.includesImages) && options.appliesToAll($0)
        }
        out += """

            // MARK: - \(kind.suffix) Symbols -

            @available(\(availability))
            extension \(type) {
            \(swiftScope(included, depth: 0, kind: kind, type: type, indent: "    "))
            }

            """
    }
    return out + "\n" + (modern ? "" : backwardsDeploymentSupport)
}

func listedAssets(_ assets: [CatalogAsset], kind: AssetKind, options: SymbolOptions) -> [CatalogAsset] {
    assets.filter { $0.kind == kind && (kind == .color || options.includesImages) && options.appliesToAny($0) }
        .sorted { codePointOrder($0.name, $1.name) }
}

func objcSymbols(_ assets: [CatalogAsset], options: SymbolOptions) -> String {
    var out = """
        #import <Foundation/Foundation.h>

        #if __has_attribute(swift_private)
        #define AC_SWIFT_PRIVATE __attribute__((swift_private))
        #else
        #define AC_SWIFT_PRIVATE
        #endif


        """
    let colors = listedAssets(assets, kind: .color, options: options)
    if !colors.isEmpty {
        out +=
            "/// The resource bundle ID.\nstatic NSString * const ACBundleID AC_SWIFT_PRIVATE = @\"\(options.bundleID)\";\n\n"
    }
    for (kind, listed) in [(AssetKind.color, colors), (.image, listedAssets(assets, kind: .image, options: options))] {
        var taken: Set<String> = []
        for asset in listed {
            let symbol = kind.objcPrefix + (asset.namespaces + [asset.name]).map(objcName).joined()
            guard taken.insert(symbol).inserted else {
                out +=
                    "#warning The \"\(fullName(asset))\" \(kind.noun) asset name resolves to the symbol \"\(symbol)\" which already exists. Try renaming the asset.\n\n"
                continue
            }
            out +=
                "/// The \"\(fullName(asset))\" asset catalog \(kind.noun) resource.\nstatic NSString * const \(symbol) AC_SWIFT_PRIVATE = @\"\(fullName(asset))\";\n\n"
        }
    }
    return out + "#undef AC_SWIFT_PRIVATE\n"
}

func symbolIndex(_ assets: [CatalogAsset], options: SymbolOptions) -> [String: Any] {
    func entries(_ kind: AssetKind) -> [[String: String]] {
        listedAssets(assets, kind: kind, options: options).map {
            [
                "catalogPath": $0.catalog.path,
                "objcSymbol": kind.objcPrefix + objcName($0.name),
                "swiftSymbol": escaped(swiftName($0.name, kind: kind)),
                "relativePath": $0.relativePath,
            ]
        }
    }
    return ["colors": entries(.color), "images": entries(.image), "symbols": [[String: String]]()]
}
