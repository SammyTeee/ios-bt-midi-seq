// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SequenceCore",
    products: [.library(name: "SequenceCore", targets: ["SequenceCore"])],
    targets: [
        .target(name: "SequenceCore", path: "Sources/Core"),
        .testTarget(name: "SequenceCoreTests", dependencies: ["SequenceCore"], path: "Tests")
    ]
)
