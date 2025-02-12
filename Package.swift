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
            "ssl",
        ]),
        .binaryTarget(
            name: "ssl",
            url: "https://github.com/Lakr233/openssl-spm/releases/download/storage.3.4.1/libssl.xcframework.zip",
            checksum: "14d39f64b96b753a38a8453dcc471bdf09d6b101b1f26e603c81b135706a92a9"
        ),
    ]
)
