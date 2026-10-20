// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "MandelbulberMac",
    platforms: [.macOS("27.0")],
    products: [.executable(name: "MandelbulberMac", targets: ["MandelbulberMac"])],
    dependencies: [.package(path: "../FractalEngine")],
    targets: [
        .executableTarget(name: "MandelbulberMac", dependencies: ["FractalEngine"],
                          resources: [.copy("Shaders/Mandelbulb.metal")]),
        .testTarget(name: "MandelbulberMacTests", dependencies: ["MandelbulberMac"])
    ]
)
