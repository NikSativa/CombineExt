// swift-tools-version:5.10
// swiftformat:disable all
import PackageDescription

let package = Package(
    name: "CombineExt",
    platforms: [
        .iOS(.v16),
        .macOS(.v14),
        .macCatalyst(.v16),
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
