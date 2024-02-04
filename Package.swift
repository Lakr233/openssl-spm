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
            url: "https://github.com/Lakr233/openssl-spm/releases/download/storage.3.2.1/libssl.xcframework.zip",
            checksum: "9522f46c3bb0c9486434b11c3b87ca8c846978f457604731765c1f9239c93446"
        ),
    ]
)
