// swift-tools-version:5.9
// swiftformat:disable all
import PackageDescription

let package = Package(
    name: "NValueSubject",
    platforms: [
        .iOS(.v13),
        .macOS(.v11),
        .macCatalyst(.v13),
        .visionOS(.v1),
        .tvOS(.v13),
        .watchOS(.v6)
    ],
    products: [
        .library(name: "NValueSubject", targets: ["NValueSubject"])
    ],
    dependencies: [
    ],
    targets: [
        .target(name: "NValueSubject",
                dependencies: [
                ],
                path: "Source",
                resources: [
                    .copy("../PrivacyInfo.xcprivacy")
                ]),
        .testTarget(name: "NValueSubjectTests",
                    dependencies: [
                        "NValueSubject"
                    ],
                    path: "Tests"),
    ]
)
