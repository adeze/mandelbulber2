# Native Mac reference preview

Swift 6 / macOS 27 reference host for the independent `FractalEngine` package and native Metal compute. This is not the production application or an Apple Vision Pro renderer. Reality Composer Pro / visionOS work takes priority over expanding this Mac UI.

`rtk swift test --package-path native/MandelbulberMac` builds the executable and runs two focused tests. The actual GPU test checks 12 Metal distance estimates against the Swift Double engine and every pixel for finite bounded output and a non-empty silhouette. It writes `/tmp/mandelbulber-native-metal.png` for inspection. Metal unavailability is a failure, not a CPU fallback.

`rtk ./script/build_and_run.sh` at repository root builds and stages a local `.app` with its SwiftPM shader resource bundle, then launches through Launch Services. The same script supports `--verify`, `--logs`, `--telemetry` and `--debug`. This is a development bundle, not signed/notarized distribution.

The SwiftUI window owns a preview store. Shader compilation runs off the main actor; command submission waits asynchronously for GPU completion. A `LowLevelTexture` receives the Metal compute output directly, and `TextureResource(from:)` exposes it to a RealityKit unlit image plane. The fixed camera views that plane; it is not volumetric geometry or a spatial fractal surface.

Scope: classic power-8 Mandelbulb, zero angular offsets, 32 iterations, bailout 8, 128 ray steps, 256px UI preview (renderer also permits 512px). Regenerate, indeterminate progress, errors and numerical diagnostics are implemented. No scene import, materials, animation, full formula coverage, depth integration or GPU cancellation is claimed. Closing a view does not interrupt an already submitted Metal command.

Derived formula and shader code retains Mandelbulber GPL-3.0-or-later licensing; see `mandelbulber2/COPYING`. No Qt, Rust, third-party packages or external services are used.
