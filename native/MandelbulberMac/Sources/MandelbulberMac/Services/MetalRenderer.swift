// SPDX-License-Identifier: GPL-3.0-or-later
import FractalEngine
import Metal
import RealityKit

enum PreviewError: LocalizedError {
    case failed(String)
    var errorDescription: String? {
        switch self { case .failed(let message): message }
    }
}

struct PreviewResult {
    let texture: TextureResource
    let hits: Int
    let maximumError: Double
    let deviceName: String
    let rgba: [UInt8]
    let size: Int
}

@MainActor
final class MetalRenderer {
    private let device: any MTLDevice
    private let queue: any MTLCommandQueue
    private let samplePipeline: any MTLComputePipelineState
    private let previewPipeline: any MTLComputePipelineState

    init() async throws {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else {
            throw PreviewError.failed("Metal device or command queue unavailable.")
        }
        self.device = device
        self.queue = queue
        guard let url = Bundle.module.url(forResource: "Mandelbulb", withExtension: "metal") else {
            throw PreviewError.failed("Bundled Metal shader missing.")
        }
        let source = try String(contentsOf: url, encoding: .utf8)
        let pipelines = try await Task.detached {
            let options = MTLCompileOptions()
            options.mathMode = .safe
            let library = try device.makeLibrary(source: source, options: options)
            guard let samples = library.makeFunction(name: "samples"),
                  let preview = library.makeFunction(name: "preview") else {
                throw PreviewError.failed("Metal shader entry points missing.")
            }
            return (try device.makeComputePipelineState(function: samples),
                    try device.makeComputePipelineState(function: preview))
        }.value
        (samplePipeline, previewPipeline) = pipelines
    }

    func render(size: Int = 256) async throws -> PreviewResult {
        guard size == 256 || size == 512 else {
            throw PreviewError.failed("Preview resolution must be 256 or 512 pixels.")
        }
        let points: [SIMD4<Float>] = [
            [2, 0.3, 0.2, 0], [-2, 0.4, -0.3, 0], [0.3, 2, 0.7, 0], [0.3, -0.4, 2, 0],
            [1.2, 0.3, 0.2, 0], [-1.2, 0.3, 0.2, 0], [0, 0, 0, 0],
            [1e-22, -1e-22, 1e-22, 0], [1e-6, -2e-6, 1e-6, 0],
            [0.1, 0.1, 0.1, 0], [-0.2, 0.15, 0.1, 0], [9, 0, 0, 0]
        ]
        let stride = MemoryLayout<SIMD4<Float>>.stride
        guard let input = device.makeBuffer(bytes: points, length: points.count * stride),
              let samples = device.makeBuffer(length: points.count * stride, options: .storageModeShared),
              let pixels = device.makeBuffer(length: size * size * stride, options: .storageModeShared),
              let commands = queue.makeCommandBuffer() else {
            throw PreviewError.failed("Metal buffer or command allocation failed.")
        }
        let lowLevel = try LowLevelTexture(descriptor: .init(
            pixelFormat: .rgba8Unorm, width: size, height: size,
            textureUsage: [.shaderRead, .shaderWrite]))
        let texture = lowLevel.replace(using: commands)
        guard let encoder = commands.makeComputeCommandEncoder() else {
            throw PreviewError.failed("Metal compute encoder unavailable.")
        }
        encoder.setComputePipelineState(samplePipeline)
        encoder.setBuffer(input, offset: 0, index: 0)
        encoder.setBuffer(samples, offset: 0, index: 1)
        encoder.dispatchThreads(.init(width: points.count, height: 1, depth: 1),
                                threadsPerThreadgroup: .init(width: 12, height: 1, depth: 1))
        encoder.setComputePipelineState(previewPipeline)
        encoder.setBuffer(pixels, offset: 0, index: 0)
        encoder.setTexture(texture, index: 0)
        encoder.dispatchThreads(.init(width: size, height: size, depth: 1),
                                threadsPerThreadgroup: .init(width: 8, height: 8, depth: 1))
        encoder.endEncoding()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            commands.addCompletedHandler { completed in
                if completed.status == .completed { continuation.resume() }
                else { continuation.resume(throwing: PreviewError.failed(
                    completed.error?.localizedDescription ?? "Metal command failed.")) }
            }
            commands.commit()
        }
        try Task.checkCancellation()
        let actual = samples.contents().bindMemory(to: SIMD4<Float>.self, capacity: points.count)
        var maximumError = 0.0
        for (index, point) in points.enumerated() {
            let reference = try Mandelbulb.estimate(at: SIMD3(Double(point.x), Double(point.y), Double(point.z)))
            let value = actual[index]
            let error = abs(Double(value.x) - reference.distance)
            guard value.x.isFinite, error <= 3e-4 + 1e-3 * abs(reference.distance),
                  value.y == (reference.escaped ? 1 : 0), value.z == Float(reference.iterations) else {
                throw PreviewError.failed("Metal/Swift distance estimate mismatch at sample \(index).")
            }
            maximumError = max(maximumError, error)
        }
        let values = pixels.contents().bindMemory(to: SIMD4<Float>.self, capacity: size * size)
        var hits = 0
        var rgba: [UInt8] = []
        rgba.reserveCapacity(size * size * 4)
        for index in 0..<(size * size) {
            let value = values[index]
            guard value.x.isFinite, value.y.isFinite, value.z.isFinite,
                  value.x >= 0, value.x <= 1, value.y >= 0, value.y <= 1,
                  value.z >= 0, value.z <= 1, value.w == 0 || value.w == 1 else {
                throw PreviewError.failed("Non-finite or invalid Metal preview pixel.")
            }
            hits += Int(value.w)
            rgba.append(contentsOf: [UInt8(value.x * 255), UInt8(value.y * 255), UInt8(value.z * 255), 255])
        }
        guard hits > 0, hits < size * size else {
            throw PreviewError.failed("Metal preview silhouette is empty or fills the image.")
        }
        let resource = try await TextureResource(from: lowLevel)
        return PreviewResult(texture: resource, hits: hits, maximumError: maximumError,
                             deviceName: device.name, rgba: rgba, size: size)
    }
}
