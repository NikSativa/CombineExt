// swift-tools-version:6.0
// swiftformat:disable all
import PackageDescription

let package = Package(
    name: "CombineExt",
    platforms: [
        .iOS(.v13),
        .macOS(.v11),
        .macCatalyst(.v13),
        .visionOS(.v1),
        .tvOS(.v13),
        .watchOS(.v6)
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
