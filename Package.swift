// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TouchDSH",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "TouchDSHTouchBar", targets: ["TouchDSHTouchBar"]),
        .executable(name: "TouchDSHMenu", targets: ["TouchDSHMenu"])
    ],
    targets: [
        .target(
            name: "TouchBarPrivate",
            publicHeadersPath: "include",
            linkerSettings: [.linkedFramework("AppKit")]
        ),
        .target(name: "TouchDSHCore"),
        .target(
            name: "TouchDSHShared",
            dependencies: ["TouchDSHCore"],
            resources: [.process("Resources")],
            linkerSettings: [.linkedFramework("AppKit"), .linkedFramework("ServiceManagement")]
        ),
        .executableTarget(
            name: "TouchDSHTouchBar",
            dependencies: ["TouchDSHCore", "TouchDSHShared", "TouchBarPrivate"],
            linkerSettings: [.linkedFramework("AppKit")]
        ),
        .executableTarget(
            name: "TouchDSHMenu",
            dependencies: ["TouchDSHShared"],
            linkerSettings: [.linkedFramework("AppKit")]
        ),
        .testTarget(name: "TouchDSHCoreTests", dependencies: ["TouchDSHCore"])
    ]
)
