// SPDX-License-Identifier: GPL-3.0-or-later
import XCTest
import AppKit
@testable import MandelbulberMac

final class MetalPreviewTests: XCTestCase {
    @MainActor
    func testActualMetalPreviewAgainstSwiftReference() async throws {
        let renderer = try await MetalRenderer()
        let result = try await renderer.render()
        XCTAssertGreaterThan(result.hits, 0)
        XCTAssertLessThan(result.hits, 256 * 256)
        XCTAssertLessThan(result.maximumError, 3e-4)
        XCTAssertEqual(result.rgba.count, 256 * 256 * 4)
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 256, pixelsHigh: 256,
                                      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                      isPlanar: false, colorSpaceName: .deviceRGB,
                                      bytesPerRow: 256 * 4, bitsPerPixel: 32)
        let image = try XCTUnwrap(bitmap)
        result.rgba.withUnsafeBytes { bytes in
            image.bitmapData?.update(from: bytes.baseAddress!.assumingMemoryBound(to: UInt8.self),
                                     count: bytes.count)
        }
        let png = try XCTUnwrap(image.representation(using: .png, properties: [:]))
        try png.write(to: URL(fileURLWithPath: "/tmp/mandelbulber-native-metal.png"))
        print("Metal GPU: \(result.deviceName); sample max error: \(result.maximumError); hit pixels: \(result.hits)")
    }

    @MainActor
    func testUnsupportedResolutionRejected() async throws {
        let renderer = try await MetalRenderer()
        do {
            _ = try await renderer.render(size: 1)
            XCTFail("Unsupported resolution accepted")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("256 or 512"))
        }
    }
}
