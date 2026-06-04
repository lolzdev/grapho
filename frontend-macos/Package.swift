// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "GraphoMac",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "GraphoMac", targets: ["GraphoMac"])
    ],
    targets: [
        .executableTarget(
            name: "GraphoMac",
            path: "Sources/GraphoMac",
            linkerSettings: [
                // Adjust these paths if your Cabal/GHC version emits a different library name or directory.
                .unsafeFlags([
                    "-L", "../build/lib",
                    "-lgrapho-core",
                    "-lgrapho_runtime",
                    "-Xlinker", "-rpath",
                    "-Xlinker", "@executable_path/../Frameworks",
                    "-Xlinker", "-rpath",
                    "-Xlinker", "@executable_path/../../../build/lib",
                    "-Xlinker", "-rpath",
                    "-Xlinker", "../build/lib"
                ])
            ]
        )
    ]
)
