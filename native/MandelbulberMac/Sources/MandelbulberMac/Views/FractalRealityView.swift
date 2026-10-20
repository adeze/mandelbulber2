// SPDX-License-Identifier: GPL-3.0-or-later
import RealityKit
import SwiftUI

struct FractalRealityView: View {
    var texture: TextureResource?

    var body: some View {
        RealityView { content in
            content.camera = .virtual
            let camera = PerspectiveCamera()
            camera.look(at: .zero, from: [0, 0, 2.8], relativeTo: nil)
            content.add(camera)
            let plane = ModelEntity(mesh: .generatePlane(width: 2, height: 2),
                                    materials: [UnlitMaterial(color: .black)])
            plane.name = "FractalImagePlane"
            if let texture { plane.model?.materials = [UnlitMaterial(texture: texture)] }
            content.add(plane)
        } update: { content in
            if let texture,
               let plane = content.entities.first(where: { $0.name == "FractalImagePlane" }) as? ModelEntity {
                plane.model?.materials = [UnlitMaterial(texture: texture)]
            }
        }
        .accessibilityLabel("Raymarched Mandelbulb preview displayed on a flat image plane")
    }
}
