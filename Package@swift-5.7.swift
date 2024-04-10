// swift-tools-version:5.7
// swiftformat:disable all
import PackageDescription

let package = Package(
    name: "CombineExt",
    platforms: [
        .iOS(.v13),
        .macOS(.v11),
        .macCatalyst(.v13),
        .tvOS(.v13),
        .watchOS(.v6)
    ],
    products: [
        .library(name: "CombineExt", targets: ["CombineExt"])
    ],
    targets: [
        .target(name: "CombineExt",
                dependencies: [
                ],
                path: "Source",
                resources: [
                    .copy("../PrivacyInfo.xcprivacy")
                ]),
        .testTarget(name: "CombineExtTests",
                    dependencies: [
                        "CombineExt"
                    ],
                    path: "Tests"),
    ]
)
