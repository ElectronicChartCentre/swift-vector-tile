// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-vector-tile",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(
            name: "SwiftVectorTile",
            targets: ["SwiftVectorTile"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-protobuf", from: "1.35.1"),
        .package(url: "https://github.com/ElectronicChartCentre/swift-geo", from: "0.0.7"),
        //.package(path: "../swift-geo"),
    ],
    targets: [
        .target(
            name: "SwiftVectorTile",
            dependencies: [
                .product(name: "SwiftProtobuf", package: "swift-protobuf"),
                .product(name: "SwiftGeo", package: "swift-geo"),
            ],
        )
    ]
)
