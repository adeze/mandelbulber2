# Mandelbulber modernization handoff — 2026-10-20

## Decisions

- Migrate Widgets incrementally to Qt Quick/QML, retaining existing scene/render behaviour. First slice: navigation dock action panel.
- Rust, SwiftUI/Liquid Glass, GPUI and a complete UI rewrite are deferred.
- Port OpenCL compute arithmetic to Vulkan GLSL `.comp`, package with Qt Shader Tools/QSB. This is a kernel/host-buffer migration, not a file-extension change.
- Qt Quick 3D custom materials/effects/geometry are possible later preview tools; no Quick 3D UI integration exists yet.

## Implemented and verified

- Root CMake 3.24+ entrypoint, Ninja Debug/Release presets, target-scoped dependencies, C++20, optional legacy OpenCL/OpenMP/image/audio features, synchronized development resources and macOS bundles. Historical qmake files remain but do not package the new QML module; use CMake.
- Qt 6.12.0 / Apple Clang / arm64: both complete C++20 Debug and Release builds passed.
- Release CTest: application regression suite and Metal probe passed, 159.28 seconds total. Debug's bulk example test hit QtTest's 300-second timeout during legacy animation migration. User's crash report matched test PID 35021 and QtTest Watchdog SIGABRT, not the GUI session.
- GUI was launched and inspected; user confirmed operation, then closed it. Leave it closed unless needed/requested.
- `tests/qrhi`: isolated classic power-8 Mandelbulb compute proof on Apple M4 Pro; 12 CPU-double reference points, max absolute DE error 2.9833e-7, 64x64 raymarch with 696 hit pixels. It is not the application's renderer and does not prove full scene parity or speed.
- Portable OpenCL host vector indexing fixes and a Qt 6 audio format/local URL correction.
- All 13 official Qt skills installed project-locally via `bunx --bun skills add https://github.com/TheQtCompanyRnD/agent-skills --agent codex --skill '*' --yes --copy`; `skills-lock.json` records provenance. No global skills installation.
- `.codex/config.toml`: project-local Qt docs HTTP MCP and Mandelbulber stdio MCP. Codex CLI recognizes both; Qt docs initialize/tools-list and a live QRhiWidget documentation search succeeded. The exact configured stdio command also passed initialization, tool listing and example discovery. MCP tools become available to this chat after restart.
- `tools/mcp`: official Python SDK/uv server wrapping existing CPU CLI, six discovery/read/render/status/cancel/image tools. Repository-confined trusted scenes, unique output directories, one active render, 512px dimension cap, 120-second timeout, bounded captured logs and disconnect cleanup. Five tests passed including real 16x16 render through an official MCP stdio client. Not live GUI control or a sandbox for untrusted native scenes.
- `qml/Mandelbulber/Gui/RenderControls.qml` and `qt/render_controls.*`: first real QML panel embedded through QQuickWidget in dock_navigation.ui. Render/Stop/Undo/Redo/Navigator retain existing slots, icons, tooltips, animation locks and Navigator-specific hiding. Qt QuickWidgets/QuickControls2 dependencies and qt_add_qml_module added. Height changes are queued to avoid re-entering Metal frames during layout.
- Release QML build and generated qmllint target pass. `tests/quick` covers real clicks, disabled/re-enabled actions, navigation hiding, packaged QML loading, forwarding and height changes. Native macOS style/Metal wrapper test passes with all warnings fatal. Full application regression passed in 189.18s and Metal shader probe in 0.48s; after fixing the test host to match actual embedding, both integrated QML tests passed in 0.77s. The initial combined run failed only on an offscreen top-level size-hint warning; test now embeds the wrapper in a fixed host, without warning suppression.
- Desktop automation timed out twice, but direct macOS window capture succeeded: /tmp/mandelbulber-qml-gui.png. Integrated app visually inspected with new panel, startup render completed; log confirms Apple M4 Pro Metal for Qt Quick. Legacy startup still warns about missing Monospace font alias. Existing translation catalogs and QWidget-specific spacing preferences do not cover new QML text/layout yet.
- The newly rebuilt Release app is currently open for inspection (PID 78476 at verification); no other GUI version was launched. Final native wrapper test passed in 342ms without warnings. Keyboard traversal across Widgets/QML boundaries remains untested manually.
- `docs/renderer-modernisation.md`: proposed QQuickRhiItem viewport, Shader Tools ABI, ownership/cancellation/precision gates, optional later Quick3D geometry integration. SCXML is recommended for one future backend lifecycle controller; no SCXML dependency or new production GPU renderer added.

## Commands

```sh
cmake --preset qt6-release -DMANDELBULBER_BUILD_QRHI_TEST=ON -DCMAKE_PREFIX_PATH='/opt/homebrew;/opt/homebrew/opt/opencl-clhpp-headers'
cmake --build --preset qt6-release --parallel 6
ctest --preset qt6-release
MANDELBULBER_MCP_INTEGRATION=1 uv run --locked --project tools/mcp python -m unittest discover -s tools/mcp -v
```

Installed local build dependencies: CMake, Ninja, Qt 6.12 split modules, GSL and OpenCL C++ headers; existing Homebrew image/audio/OpenMP libraries are used. Bundles depend on installed libraries; packaging/signing/notarization are not done. No commits, pushes or deployments.

## Next work

1. Check integrated keyboard traversal, then migrate a parameter panel through a typed backend model. Do not move scene data into QML.
2. Follow docs/renderer-modernisation.md for a bounded QQuickRhiItem GPU viewport; preserve CPU/OpenCL reference paths and error/cancellation behavior.
3. Compare real scene outputs before expanding formulas, hybrids, materials, textures and post-effects. FP64 still requires an explicit CPU/reference path on Metal.
4. Profile legacy animation migration, then improve render-job state/cancellation and searchable parameter/dock UX. No performance gain from language/framework changes has been established.
5. Application MCP currently renders repository scenes via the existing CLI. Editing live GUI state requires a deliberate application command interface, not Qt's documentation MCP.
