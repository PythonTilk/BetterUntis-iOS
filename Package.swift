// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BetterUntis",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "BetterUntis",
            targets: ["BetterUntis"])
    ],
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.8.0"),
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "BetterUntis",
            dependencies: [
                "Alamofire",
                .product(name: "Collections", package: "swift-collections")
            ],
            path: "BetterUntis"
        ),
        .testTarget(
            name: "BetterUntisTests",
            dependencies: ["BetterUntis"],
            path: "BetterUntisTests"
        )
    ]
)