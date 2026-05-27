// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OpenSSL",
    products: [
        .library(name: "OpenSSL", targets: ["OpenSSL"]),
    ],
    targets: [
        .target(name: "OpenSSL", dependencies: [
            "libssl",
        ]),
        .binaryTarget(
            name: "libssl",
            url: "https://github.com/Lakr233/openssl-spm/releases/download/storage.4.0.0/libssl.xcframework.zip",
            checksum: "a28bedbd935d76e032240ea9a156e789a028cfa370eab5e44d3d2fdcbdf395b8"
        ),
    ]
)
