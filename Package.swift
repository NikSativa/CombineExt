// swift-tools-version:6.0
// swiftformat:disable all
import PackageDescription

let package = Package(
    name: "CombineExt",
    platforms: [
        .iOS(.v15),
        .macOS(.v14),
        .macCatalyst(.v15),
        .visionOS(.v1),
        .tvOS(.v16),
        .watchOS(.v9)
    ],
    products: [
        .library(name: "CombineExt", targets: ["CombineExt"]),
        .library(name: "CombineExtStatic", type: .static, targets: ["CombineExt"]),
        .library(name: "CombineExtDynamic", type: .dynamic, targets: ["CombineExt"])
    ],
    targets: [
        .target(name: "CombineExt",
                dependencies: [
                ],
                path: "Source",
                resources: [
                    .process("PrivacyInfo.xcprivacy")
                ]),
        .testTarget(name: "CombineExtTests",
                    dependencies: [
                        "CombineExt"
                    ],
                    path: "Tests"),
    ]
)
