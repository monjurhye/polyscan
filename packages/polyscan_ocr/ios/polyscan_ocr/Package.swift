// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "polyscan_ocr",
    platforms: [
        .iOS("15.0")
    ],
    products: [
        .library(name: "polyscan-ocr", targets: ["polyscan_ocr"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        // Built by ios/scripts/build_tesseract.sh; not checked in.
        .binaryTarget(name: "TesseractC", path: "TesseractC.xcframework"),
        .target(
            name: "polyscan_ocr",
            dependencies: [
                "TesseractC",
                .product(name: "FlutterFramework", package: "FlutterFramework"),
            ],
            resources: [
                .process("PrivacyInfo.xcprivacy")
            ],
            linkerSettings: [
                .linkedLibrary("c++")
            ]
        ),
    ]
)
