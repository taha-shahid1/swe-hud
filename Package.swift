// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "HUD",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "HUD",
            path: "Sources/HUD",
            linkerSettings: [
                .linkedFramework("Carbon")
            ]
        )
    ]
)
