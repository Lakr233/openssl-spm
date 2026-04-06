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
            url: "https://github.com/Lakr233/openssl-spm/releases/download/storage.3.6.0/libssl.xcframework.zip",
            checksum: "a72bf9c2987901fca87288233b4ea358e476115b28ef8fd42c94be544fe6e613"
        ),
    ]
)
