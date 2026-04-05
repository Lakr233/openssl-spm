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
            checksum: "b2a4d0b3e88cfbf0eacaec1c04dfea04a789f33432bc42b9371d3a6e78f65289"
        ),
    ]
)
