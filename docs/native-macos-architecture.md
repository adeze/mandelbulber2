# Native macOS fractal application

Decision: build a separate SwiftUI + Metal application targeting macOS 27, with
RealityKit as the scene/asset presentation layer where useful. Preserve the
working Qt application as the behavioural and numerical reference. This replaces
the earlier QML migration direction; it does not delete that implementation.

## Verified environment

Checked 2026-10-20: Xcode 27.1 (27A9275), Apple Swift 6.4, macOS SDK 27.0,
host macOS 27.0.1, arm64. The selected SDK exposes `RealityView`, `LowLevelTexture`
and `LowLevelMesh` on macOS 15 and later. A macOS 27 deployment target is compatible
with these APIs; no Qt runtime is needed by the new application.

Verification commands: `xcodebuild -version`, `xcrun swift --version`,
`xcrun --sdk macosx --show-sdk-version`, and SDK Swift interface inspection.
Apple documentation was checked through Xcode DocumentationSearch.

## First complete slice

1. Port the existing fixed classic power-8 Mandelbulb reference into a small Swift
   engine, retaining its exact supported settings and explicit unsupported cases.
   Use the existing QRhi probe's numerical cases as fixtures, independently of Qt.
2. Implement the matching Metal compute kernel and a bounded colour-image preview.
   Add camera controls, formula parameters, render/stop, progress and error state.
   Keep authoritative scene parameters and CPU calculations in `Double`; create
   a validated `Float` snapshot only at the GPU boundary.
3. Present the GPU result in a SwiftUI editor. Use `MTKView` for the first direct
   image viewport, or demonstrate the RealityKit texture path below if a 3D scene
   presentation is required immediately. Do not make scene integration a condition
   for validating the fractal calculation.
4. Gate completion on Swift CPU reference tests, Metal readback comparison,
   resize/cancellation/stale-result checks, and visual keyboard/accessibility review.
   A plausible screenshot alone does not establish renderer parity.

This slice does not import arbitrary `.fract` scenes, reproduce materials,
lighting, hybrids, animation or convert hundreds of formulas. Add each capability
only with explicit coverage and a known scene reference. No automatic C++/OpenCL
to Swift/Metal translator is assumed.

## Ownership and boundaries

| Component | Responsibility | Dependencies |
|---|---|---|
| FractalCore | Immutable scene/camera values, formula evaluation, Double reference, validation | Swift standard library/Foundation; no UI or GPU |
| FractalMetal | Float conversion, Metal resources/pipelines, bounded dispatch and readback | FractalCore, Metal |
| Native app | SwiftUI window, inspector, commands, file workflows, observable job state | FractalCore, FractalMetal, SwiftUI |
| RealityKit presentation | Texture/material entities; later imported or extracted meshes | RealityKit; receives renderer outputs |

These are ownership boundaries, not a requirement to create four packages now.
Use SwiftPM for the portable core and tests; app bundling and Metal resource
compilation must be verified separately from `swift test`.

One owner controls each render job: immutable scene snapshot, generation ID,
progress, cancellation and terminal result. SwiftUI observes main-actor state;
CPU work runs off the main actor. Obsolete work must not overwrite a newer frame.
Cancellation stops scheduling new batches and discards obsolete completions;
submitted GPU work still needs safe resource lifetime and completion handling.
Do not recreate Qt State Machine/SCXML dependencies in the native app.

## RealityKit integration: exact limits

Apple's [`LowLevelTexture`](https://developer.apple.com/documentation/realitykit/lowleveltexture)
supports frequently updated texture data from Metal compute. Create one texture
descriptor with compatible format, size and `.shaderRead`/`.shaderWrite` usage;
create a [`TextureResource(from:)`](https://developer.apple.com/documentation/realitykit/textureresource/init(from:)-17ght)
from it. On the main actor, obtain the writable `MTLTexture` with
[`replace(using:)`](https://developer.apple.com/documentation/realitykit/lowleveltexture/replace(using:)).
Encode the fractal kernel into the supplied command buffer and populate every
displayed pixel: replacement contents start uninitialized. RealityKit waits for
that command buffer before rendering the texture. Keep device compatibility,
resize replacement, error reporting and resource lifetime explicit.

Use that resource on an unlit material on a plane displayed by
[`RealityView`](https://developer.apple.com/documentation/realitykit/realityview).
This is an image inside a 3D scene. Its visibility, hit testing and depth belong
to the plane, not to the raymarched fractal surface. It does not provide true
fractal/mesh intersection, per-pixel occlusion, shared shadows, collisions or
reflections. An orbiting scene camera does not automatically update fractal rays;
camera mapping and rerendering must be defined explicitly.

True mixed geometry needs either a separately verified depth-compositing renderer
or an extracted mesh. [`LowLevelMesh`](https://developer.apple.com/documentation/realitykit/lowlevelmesh)
supports CPU/GPU-updated vertex/index buffers, but is not an implicit-surface
mesher. Mesh extraction requires its own resolution, topology, normal and bounds
validation and loses detail below sampling resolution. Defer this until needed.

RealityKit [`CustomMaterial`](https://developer.apple.com/documentation/realitykit/modifying-realitykit-rendering-using-custom-materials)
provides surface shaders and geometry modifiers within its mesh pipeline; that
does not make it a drop-in full Mandelbulber raymarch renderer. Newer low-level
APIs surfaced by documentation search must be checked against actual selected SDK
imports before adoption; the first slice does not depend on them.

## Validation and migration gates

- Preserve Double scene values through serialization and editing. Reject nonfinite
  values, invalid camera/ray bounds and settings unsupported by the preview.
- Compare distance estimates, hit/miss, normals and images against CPU references
  with declared tolerances. Record GPU precision; deep zoom and boundary cases
  cannot silently inherit Double-quality claims from a Float preview.
- Test GPU errors, cancellation, rapid edits and resize while work is in flight.
  Limit preview resolution, iteration count and concurrent work before dispatch.
- Treat the old application as an oracle, not a native runtime dependency. A CLI
  comparison harness may invoke it during migration without linking Qt into the
  new app. Do not offer unsupported scenes as successfully converted.
- Ship only after real app-bundle/resource loading and Metal/RealityKit execution
  are verified on the target OS. This document establishes architecture, not
  implementation, measured speed or full-engine compatibility.

