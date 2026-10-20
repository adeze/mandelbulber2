// SPDX-License-Identifier: GPL-3.0-or-later
import SwiftUI

struct ContentView: View {
    @State private var store = PreviewStore()
    @State private var inspectorVisible = true

    var body: some View {
        NavigationSplitView {
            List {
                Label("Mandelbulb", systemImage: "sparkles")
                Text("Fixed power 8 preview").font(.caption).foregroundStyle(.secondary)
            }
            .navigationTitle("Fractals")
            .navigationSplitViewColumnWidth(min: 180, ideal: 210, max: 260)
        } detail: {
            VStack(spacing: 0) {
                FractalRealityView(texture: store.result?.texture)
                    .overlay {
                        if store.isRendering && store.result == nil {
                            ProgressView(store.status)
                        }
                    }
                Divider()
                HStack {
                    if store.isRendering { ProgressView().controlSize(.small) }
                    Text(store.status).font(.callout).foregroundStyle(.secondary)
                    Spacer()
                    Text("Metal → RealityKit image plane").font(.caption).foregroundStyle(.secondary)
                }
                .padding(12)
                if let error = store.error {
                    Text(error).foregroundStyle(.red).textSelection(.enabled).padding()
                }
            }
            .navigationTitle("Mandelbulb")
            .toolbar {
                Button {
                    Task { await store.regenerate() }
                } label: {
                    Label("Regenerate", systemImage: "arrow.clockwise")
                }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(store.isRendering)
                Button("Inspector", systemImage: "sidebar.right") { inspectorVisible.toggle() }
            }
            .inspector(isPresented: $inspectorVisible) {
                PreviewInspector(result: store.result)
                    .inspectorColumnWidth(min: 240, ideal: 270, max: 320)
            }
        }
        .frame(minWidth: 850, minHeight: 560)
        .task { await store.regenerate() }
    }
}
