// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FractalEngine",
    platforms: [.macOS("27.0")],
    products: [.library(name: "FractalEngine", targets: ["FractalEngine"])],
    targets: [
        .target(name: "FractalEngine"),
        .testTarget(name: "FractalEngineTests", dependencies: ["FractalEngine"])
    ]
)
