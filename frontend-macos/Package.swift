// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Grapho",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Grapho", targets: ["Grapho"])
    ],
    targets: [
        .executableTarget(
            name: "Grapho",
            path: "Sources/Grapho",
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
