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
            url: "https://github.com/Lakr233/openssl-spm/releases/download/storage.3.3.0/libssl.xcframework.zip",
            checksum: "1fb58bb47c7439e4fb44bd3c03d1a4fd6de204a545dc9400ebe414a6414795b3"
        ),
    ]
)
