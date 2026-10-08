// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "polyscan_scanner",
    platforms: [
        .iOS("15.0")
    ],
    products: [
        .library(name: "polyscan-scanner", targets: ["polyscan_scanner"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "polyscan_scanner",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ],
            resources: [
                .process("PrivacyInfo.xcprivacy")
            ],
            linkerSettings: [
                .linkedFramework("VisionKit")
            ]
        )
    ]
)
