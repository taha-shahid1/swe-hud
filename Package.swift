// swift-tools-version:5.10
import Foundation
import PackageDescription

// Embedded so the bare binary has a bundle ID and an Automation usage string
// (without one, Apple Events to Terminal are denied with no prompt).
let infoPlist = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    .appendingPathComponent("Support/Info.plist").path

let package = Package(
    name: "HUD",
    // 15 for ScrollPosition/onScrollGeometryChange (drag auto-scroll).
    platforms: [.macOS("15.0")],
    targets: [
        .executableTarget(
            name: "HUD",
            path: "Sources/HUD",
            linkerSettings: [
                .linkedFramework("Carbon"),
                .unsafeFlags(["-Xlinker", "-sectcreate", "-Xlinker", "__TEXT", "-Xlinker", "__info_plist", "-Xlinker", infoPlist]),
            ]
        )
    ]
)
