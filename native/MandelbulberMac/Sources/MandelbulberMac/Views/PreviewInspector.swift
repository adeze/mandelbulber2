// SPDX-License-Identifier: GPL-3.0-or-later
import SwiftUI

struct PreviewInspector: View {
    var result: PreviewResult?

    var body: some View {
        Form {
            Section("Formula") {
                LabeledContent("Type", value: "Classic Mandelbulb")
                LabeledContent("Power", value: "8")
                LabeledContent("Iterations", value: "32")
                LabeledContent("Bailout", value: "8")
            }
            Section("Preview") {
                LabeledContent("Resolution", value: "256 × 256")
                LabeledContent("Ray steps", value: "128 maximum")
                if let result {
                    LabeledContent("Surface pixels", value: result.hits.formatted())
                    LabeledContent("GPU", value: result.deviceName)
                    LabeledContent("Max DE error", value: result.maximumError.formatted(.number.precision(.significantDigits(3))))
                }
            }
            Section {
                Text("A Metal raymarch rendered onto a RealityKit image plane. This is not volumetric geometry and does not load Mandelbulber scenes.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
