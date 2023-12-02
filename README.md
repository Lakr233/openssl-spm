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
    from: "3.2.0"
)
```

## Credits:

- [https://github.com/DimaRU/Libssh2Prebuild](https://github.com/DimaRU/Libssh2Prebuild)
- [https://blog.andrewmadsen.com/2020/06/22/building-openssl-for.html](https://blog.andrewmadsen.com/2020/06/22/building-openssl-for.html)
- [https://github.com/Frugghi/iSSH2](https://github.com/Frugghi/iSSH2)
