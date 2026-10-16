// swift-tools-version:5.9
// The math engine: expression trees, differentiation, problem generators,
// answer checkers and the structured editor model. No UI code.
import PackageDescription

let package = Package(
    name: "MathEngine",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "MathEngine", targets: ["MathEngine"]),
    ],
    targets: [
        .target(name: "MathEngine"),
        .testTarget(name: "MathEngineTests", dependencies: ["MathEngine"]),
    ]
)
