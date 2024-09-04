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
            url: "https://github.com/Lakr233/openssl-spm/releases/download/storage.3.3.2/libssl.xcframework.zip",
            checksum: "b42ece46245cc63106f4dd0cae2e39b53849138cd31c4b22f232d4355bf1256e"
        ),
    ]
)
