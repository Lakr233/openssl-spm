# OpenSSL

Swift package support for OpenSSL 3.2.0+ on all Apple platform. GitHub Action will check for update each day.

| Platform          | Architectures         | Minimal Deployment Target ｜
|-------------------|-----------------------|---------------------------|
| macOS             | x86_64 arm64          | 10.15                     |
| mac Catalyst      | x86_64 arm64          | 10.15 (iOS ABI 13.1)      |
| iOS               | arm64                 | 11.0                      |
| iOS Simulator     | x86_64 arm64          | 11.0                      |
| tvOS              | arm64                 | 11.0                      |
| tvOS Simulator    | x86_64 arm64          | 11.0                      |
| watchOS           | armv7k arm64_32 arm64 | 5.0                       |
| watchOS Simulator | x86_64 arm64          | 5.0                       |
| xrOS              | arm64                 | 1.0                       |
| xrOS Simulator    | arm64                 | 1.0                       |

## Usage

Add line to you package.swift dependencies:

```
.package(
    name: "OpenSSL",
    url: "https://github.com/Lakr233/openssl-spm.git", 
    from: "4.0.0"
)
```

## Binary artifact notices

The package wrapper's MIT license is separate from the OpenSSL payload license. New builds include `Licenses/manifest.json` inside `OpenSSL.Package.xcframework`, with the source URL, full Git revision, commit tree, original notice paths and SHA-256 digests for each component. OpenSSL's actual `LICENSE*`, `NOTICE*`, `COPYING*`, `AUTHORS*` and `VERSION.dat` files are copied from the source used for compilation. The wrapper license is retained under its own component directory. Tracked source changes, if present, have an explicit `source_patch` record and sidecar.

The build requires `jq` in addition to the existing Xcode build tools. Each architecture stages its own notice context before compilation. The merge refuses missing, changed or differing contexts across platform slices, and verifies the notices after extracting the final ZIP. This changes newly built artifacts. It does not add provenance to existing release archives.

Run the host-only packaging regression with `uv run Script/test-notices.py`. It uses the actual OpenSSL 3.6.2 notice files and synthetic libraries and Apple tools. It does not compile OpenSSL or validate an Apple SDK build.

## Credits:

- [https://github.com/DimaRU/Libssh2Prebuild](https://github.com/DimaRU/Libssh2Prebuild)
- [https://blog.andrewmadsen.com/2020/06/22/building-openssl-for.html](https://blog.andrewmadsen.com/2020/06/22/building-openssl-for.html)
- [https://github.com/Frugghi/iSSH2](https://github.com/Frugghi/iSSH2)
