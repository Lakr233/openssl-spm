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
            url: "https://github.com/Lakr233/openssl-spm/releases/download/storage.3.6.1/libssl.xcframework.zip",
            checksum: "d35da5a8a3710bb1a715951ae0d5a4e1a447fca7e9dd1d07264127051a4761f9"
        ),
    ]
)
