// swift-tools-version:5.8

import PackageDescription

let package = Package(
    name: "PersistDB",
    products: [
        .library(
            name: "PersistDB",
            targets: ["PersistDB"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/Fleuronic/Schemata", branch: "master"),
        .package(url: "https://github.com/Fleuronic/ReactiveSwift", branch: "main"),
        .package(url: "https://github.com/tonyarnold/Differ", from: "1.4.3"),
    ],
    targets: [
        .target(
            name: "PersistDB",
            dependencies: [
                "Differ",
                "ReactiveSwift",
                "Schemata",
            ],
            path: "Source"
        )
    ],
    swiftLanguageVersions: [.v5]
)
