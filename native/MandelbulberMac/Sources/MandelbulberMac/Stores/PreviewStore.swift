// SPDX-License-Identifier: GPL-3.0-or-later
import Observation
import RealityKit

@MainActor @Observable
final class PreviewStore {
    var result: PreviewResult?
    var isRendering = false
    var status = "Ready"
    var error: String?
    private var renderer: MetalRenderer?

    func regenerate() async {
        guard !isRendering else { return }
        isRendering = true
        error = nil
        defer { isRendering = false }
        do {
            status = "Preparing Metal"
            if renderer == nil { renderer = try await MetalRenderer() }
            guard let renderer else { return }
            status = "Rendering and validating"
            result = try await renderer.render()
            status = "Preview ready · 12 CPU/GPU samples checked"
        } catch {
            self.error = error.localizedDescription
            status = "Preview failed"
        }
    }
}
