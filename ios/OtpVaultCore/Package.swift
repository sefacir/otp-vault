// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OtpVaultCore",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    products: [
        .library(name: "OtpVaultCore", targets: ["OtpVaultCore"])
    ],
    targets: [
        .target(name: "OtpVaultCore"),
        .testTarget(name: "OtpVaultCoreTests", dependencies: ["OtpVaultCore"])
    ]
)
