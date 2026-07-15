// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "NotePlanShortcutMaker",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "NotePlanShortcutMaker", targets: ["NotePlanShortcutMaker"])
    ],
    targets: [
        .executableTarget(
            name: "NotePlanShortcutMaker",
            path: "Sources/NotePlanShortcutMaker"
        )
    ]
)
