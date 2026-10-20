# Renderer modernisation for the Qt Quick GUI

Design status: 2026-10-20; APIs checked against Qt 6.12 documentation. This document
defines the next integration slice. It does not claim that the application renders
through Metal or Qt Quick 3D today.

## Decision

Keep the existing CPU/OpenCL renderer operational while the GUI migrates. Present
the future Metal fractal preview through a `QQuickRhiItem` and build-time Shader
Tools packages. Use Qt Quick 3D only when a feature needs a real scene of meshes,
lights or shared depth, such as a mesh-export preview. A raymarched image does not
require `View3D`, and moving it into `CustomMaterial` would not port OpenCL compute.

`QQuickRhiItem` renders to an offscreen texture that Qt Quick composites with the
interface, using the window's own QRhi/device. It is the appropriate bridge for
our existing QRhi experiment. Its renderer API is marked technology preview in
Qt 6.12 documentation; QRhi has limited compatibility guarantees. Isolate this
implementation and rebuild/test it on every Qt minor upgrade. Do not expose QRhi
types through the application parameter or scene APIs.

## Current implementation and boundaries

| Existing component | Responsibility | Migration boundary |
|---|---|---|
| `mandelbulber2/src/render_job.{hpp,cpp}` | CPU/OpenCL job orchestration, image updates, progress, post-effects | Keep scene loading, output and existing final-render semantics; adapt status once for QML |
| `mandelbulber2/src/rendered_image_widget.{hpp,cpp}` | QWidget/QPainter image presentation and interaction | Port interaction separately from image generation |
| `tests/qrhi/main.cpp` and `mandelbulb.comp` | Real Metal compute dispatch/readback and fixed Mandelbulb profile | Numerical oracle for the first Quick GPU viewport, not a reusable full renderer |
| `tests/qrhi/CMakeLists.txt` | `qt_add_shaders` packages Vulkan GLSL into `.qsb` | Reuse build-time conditioning for application shaders |

The current probe checks 12 points against an independent double reference and a
64×64 finite, bounded raymarch with foreground and background pixels. It does not
test scene parity, navigation, materials, shadows, textures, animation, HDR export,
hybrid formulas or rendering speed. The real Metal CTest was rerun successfully
while preparing this design. No shader or application code changes accompany it.

## First integrated GPU viewport

1. Expose one C++ item, provisionally `FractalPreview`, to QML. It owns GUI-facing
   properties and an immutable, validated render-request snapshot. Keep scene
   coordinates in double precision in the application model.
2. Its `QQuickRhiItemRenderer` copies a pending request during `synchronize()` and
   owns all GPU resources on the scene-graph rendering thread. Never read live
   parameter containers, QObject properties or mutable `cImage` storage in a GPU
   render callback.
3. Adapt the existing bounded Mandelbulb shader to write an RGBA32F storage buffer.
   Add a minimal fullscreen vertex/fragment pair that reads that buffer and draws
   into the item's managed render target. This avoids storage-image format and
   usage requirements for the first integration and keeps pixel data on the GPU.
   Require compute and fragment-stage storage-buffer support; report unsupported
   devices explicitly. A sampled storage texture can replace the buffer only after
   that path is validated on the intended backends.
4. Start with `sampleCount = 1` and bounded preview dimensions. Compute runs outside
   a graphics pass, ends before the fullscreen graphics pass starts, and binds the
   same pixel buffer for graphics consumption. Let QRhi track the resource use;
   do not insert unrelated native Metal commands or share a second QRhi device.
   Clear every output pixel to the chosen background at the start of a generation;
   undispatched tiles must not display uninitialised memory or a previous scene.
5. Leave existing CPU/OpenCL final renders and export in place. Until scene parity
   exists, label this viewport as an experimental fixed-formula preview. Never
   silently show it as the result of an unsupported scene.

The first production fallback remains an immutable CPU image uploaded for Quick
presentation, not an invocation of the unsupported GPU profile. Copy/publish an
image only at a completed update boundary; do not let a texture upload race the
renderer writing the same pixels. Keep the Widgets viewport until this bridge and
its camera interactions have been verified.

## Proposed shader contract for that slice

This is a new, explicit layout, not a binary copy of OpenCL/C++ scene structs.
Compile `.comp`, `.vert` and `.frag` with `qt_add_shaders`; load packaged `QShader`
objects at runtime. Shader Tools does not accept `.cl` or WGSL as its source input.

| Binding | Layout / owner | Contents |
|---|---|---|
| 0 | `std140` uniform, 128 bytes | Four camera `vec4` values: origin, forward, right, up; `uvec4` viewport/tile `(width, height, tileStart, tileCount)`; `uvec4` limits `(iterations, maxSteps, profileId, reserved)`; `vec4` controls `(bailout, hitEpsilon, maxTravel, stepScale)`; `vec4` projection `(horizontalScale, verticalScale, reserved, reserved)` |
| 1 | `std430` storage, `width * height * 16` bytes | One linear RGBA `vec4` per pixel; compute writes, fragment reads |

Use four-component fields, fixed-width host integers and explicit host offsets.
Assert every field offset and the total uniform size. Keep generation IDs on the
host; the shader does not need a truncated 64-bit request identifier. Retain the
current sample-input/output bindings in the standalone numerical test rather than
making application display buffers double as test protocols.

Validate all scalar inputs as finite, dimensions and buffer-size multiplication
against overflow/device limits, and positive travel/epsilon before allocating or
submitting. Initially accept only profile 0: the existing fixed power-8 Mandelbulb,
32 iterations, bailout 8 and zero angular offsets. Reserved fields are zero. Add
other profiles only alongside reference fixtures; iteration limits alone do not
make another formula compatible.

Keep linear computation separate from display conversion. The fullscreen pass
must apply the application's documented exposure/gamma/output transform exactly
once. Establish explicit alpha and texture orientation conventions; Qt Quick
expects premultiplied alpha when blending. Do not treat the old probe's artistic
RGB shading as production colour management or HDR output.

## Ownership, scheduling and lifecycle

- GUI thread: scene edits, validation, request generation, lifecycle notifications.
  Replace pending preview requests with the newest snapshot; do not queue every
  slider movement. Changing the scene invalidates older completion notifications.
- Worker thread: existing CPU rendering and expensive scene/asset preparation.
  Publish immutable results via queued delivery. No QML object access from workers.
- Scene-graph thread: QRhi buffers, pipelines, command recording, target resizing
  and resource destruction. Use the window's QRhi supplied by the item renderer.
  Recreate resources when device, target format, sample count or dimensions change.
  Renderer destruction/recreation is normal during scene-graph/window changes.
- GPU work: submit a bounded tile batch per update, then request another update
  only while work remains. Measure dispatch duration: a render thread separation
  does not prevent a long GPU dispatch from delaying Quick composition. Tune tile
  size using actual frame latency, not an assumed time budget.
- Cancellation: invalidate the host generation and stop scheduling subsequent
  batches. Already submitted GPU work cannot be assumed preemptible. Keep buffers
  and callback state alive until work/readbacks have completed or been safely
  torn down. Do not use the legacy unsynchronised `bool *stopRequest` across new
  thread boundaries. Treat a new generation's reset and subsequent writes as
  ordered GPU work; never overwrite in-flight mapped data from the GUI thread.
- Readback: none per interactive frame. Export and numerical tests may request
  explicit asynchronous readback, with lifetime-owned completion state and checked
  byte counts. Do not copy the offscreen test's local completion variable into a
  live-window asynchronous path or block the GUI waiting for it.

The future backend job controller owns one authoritative lifecycle:
`idle → preparing → rendering → completed`, with `failed` from active states and
`cancelling` followed by `idle` once outstanding work is drained. A Qt SCXML machine
is a suitable implementation when this controller is introduced: dispatch events
to that owner and expose derived status to QML. Do not add a parallel QML state
machine that can report completion independently. Scene parameter storage,
navigation and visual panel transitions are not SCXML job state. No SCXML
dependency is added by this design-only change.

## Where Qt Quick 3D fits

For an independent mesh preview, use a normal `View3D` with custom geometry and
materials. For genuine fractal/mesh depth interaction, first prove matching camera,
clip/depth conventions, alpha and colour space. A displayed fractal texture alone
does not provide geometry, picking, cast shadows or correct occlusion.

If shared rendering is then necessary, use `QQuick3DRenderExtension` as the QML
frontend and `QSSGRenderExtension` as its render-thread backend. Qt Quick 3D owns
the backend node returned by `updateSpatialNode()`. A standalone extension can
record offscreen work during preparation; main-mode extensions record within the
main pass and cannot freely start compute there. Reuse the tested shader/request
contract, not another renderer implementation. Do not retain per-frame Quick 3D
render data across frames. This extension is deferred until a feature requires it.

## Acceptance gates and sequence

1. **Current GUI slice:** QML controls operate the existing renderer and preserve
   scene serialization, final rendering, cancellation and saving. No GPU claim.
2. **Quick GPU proof:** fixed Mandelbulb compute → GPU buffer → fullscreen pass in
   a real QML window; no normal-frame readback. Verify resize, Retina dimensions,
   hide/show, window/resource recreation, cancel/restart and unsupported-device
   reporting. Compare the same numerical samples with the standalone oracle.
3. **Scene support:** adapt camera and one actual scene from parameter snapshots;
   compare CPU double versus GPU Float32 distance, hits, depth, normals and images
   with explicit tolerances. Unsupported settings retain CPU/OpenCL routing.
4. **Performance:** compare identical scenes, resolution, precision and quality;
   report cold shader startup, warm frame time, interaction latency, memory and
   final-render time separately. Keep the change only if it earns its cost.
5. **Expansion:** add formulas/post-effects individually, then evaluate a Quick 3D
   mesh feature. Replace existing final rendering only after coverage is proven.

Metal Float32 does not preserve CPU double/deep-zoom results automatically. Near
escape boundaries, iteration counts and distance estimates can diverge; finite
outputs and a plausible silhouette are insufficient evidence. Keep CPU double as
the correctness reference and fallback for unqualified precision/scene profiles.
Formula-specific rebasing or other precision techniques require separate proof.

## Primary references

- [Qt Shader Tools](https://doc.qt.io/qt-6/qtshadertools-index.html): prefer offline shader conditioning; runtime translation is exceptional.
- [QSB manual](https://doc.qt.io/qt-6/qtshadertools-qsb.html): shader targets and package generation.
- [QQuickRhiItem](https://doc.qt.io/qt-6/qquickrhiitem.html): Qt Quick texture integration and shared window QRhi.
- [QQuickRhiItemRenderer](https://doc.qt.io/qt-6/qquickrhiitemrenderer.html): synchronization, render-thread ownership and lifecycle.
- [QQuick3DRenderExtension](https://doc.qt.io/qt-6/qquick3drenderextension.html) and [QSSGRenderExtension](https://doc.qt.io/qt-6/qssgrenderextension.html): scene integration and render stages.
- [Qt SCXML](https://doc.qt.io/qt-6/qtscxml-index.html): optional authoritative job lifecycle implementation.
