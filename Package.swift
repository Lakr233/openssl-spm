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
            checksum: "c6b47a2a9ae66aa7fb288d0a88482f2968955e654413f6a71a20d8811ba1cfd1"
        ),
    ]
)
