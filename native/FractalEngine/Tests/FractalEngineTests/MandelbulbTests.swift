// GPLv3; golden data generated from tests/qrhi/main.cpp's independent C++ double reference.
import XCTest
@testable import FractalEngine

final class MandelbulbTests: XCTestCase {
    func testCppGoldenDistanceEstimates() throws {
        // Inputs are rounded through Float exactly as the C++ QRhi oracle's Float4 inputs.
        let cases: [(SIMD3<Float>, Double, Int)] = [
            (SIMD3(2, 0.3, 0.2), 0.72246429323341277, 1),
            (SIMD3(-2, 0.4, -0.3), 0.74549106389412356, 1),
            (SIMD3(0.3, 2, 0.7), 0.81768624442764104, 1),
            (SIMD3(0.3, -0.4, 2), 0.73968556370543681, 1),
            (SIMD3(1.2, 0.3, 0.2), 0.1471461359084992, 2),
            (SIMD3(-1.2, 0.3, 0.2), 0.15059139727772536, 2),
            (SIMD3(9, 0, 0), 9.8875105980129874, 0)
        ]
        for (point, distance, iterations) in cases {
            let actual = try Mandelbulb.estimate(at: SIMD3<Double>(point))
            XCTAssertEqual(actual.distance, distance, accuracy: 1e-12)
            XCTAssertTrue(actual.escaped)
            XCTAssertEqual(actual.iterations, iterations)
        }
    }

    func testZeroAndBoundedNonEscape() throws {
        let points: [SIMD3<Float>] = [
            .zero, SIMD3(1e-22, -1e-22, 1e-22), SIMD3(1e-6, -2e-6, 1e-6),
            SIMD3(0.1, 0.1, 0.1), SIMD3(-0.2, 0.15, 0.1)
        ]
        for point in points {
            let actual = try Mandelbulb.estimate(at: SIMD3<Double>(point))
            XCTAssertEqual(actual.distance, 0)
            XCTAssertFalse(actual.escaped)
            XCTAssertEqual(actual.iterations, 32)
        }
    }

    func testInvalidInputs() {
        for value in [Double.nan, .infinity, -.infinity, 1_000_001] {
            XCTAssertThrowsError(try Mandelbulb.estimate(at: SIMD3(value, 0, 0))) {
                XCTAssertEqual($0 as? FractalError, .invalidPoint)
            }
        }
        for direction in [SIMD3<Double>.zero, SIMD3(.nan, 0, 1)] {
            XCTAssertThrowsError(try Mandelbulb.march(origin: .zero, direction: direction)) {
                XCTAssertEqual($0 as? FractalError, .invalidDirection)
            }
        }
        let origin = SIMD3<Double>(0, -3.5, 0)
        let direction = SIMD3<Double>(0, 1, 0)
        for steps in [0, 513] {
            XCTAssertThrowsError(try Mandelbulb.march(origin: origin, direction: direction, maxSteps: steps))
        }
        for distance in [0, Double.nan, .infinity, 10_001] {
            XCTAssertThrowsError(try Mandelbulb.march(origin: origin, direction: direction, maxDistance: distance))
        }
        for tolerance in [0, Double.nan, .infinity, 2] {
            XCTAssertThrowsError(try Mandelbulb.march(origin: origin, direction: direction, tolerance: tolerance))
        }
    }

    func testBoundedRayMarch() throws {
        let origin = SIMD3<Double>(0, -3.5, 0)
        let hit = try Mandelbulb.march(origin: origin, direction: SIMD3(0, 1, 0))
        XCTAssertTrue(hit.hit)
        XCTAssertTrue(hit.travel.isFinite)
        XCTAssertTrue((0...7).contains(hit.travel))
        XCTAssertTrue((1...128).contains(hit.steps))
        let miss = try Mandelbulb.march(origin: origin, direction: SIMD3(0, -1, 0))
        XCTAssertFalse(miss.hit)
        XCTAssertEqual(miss.travel, 7)
        let limited = try Mandelbulb.march(origin: origin, direction: SIMD3(0, 1, 0), maxSteps: 1)
        XCTAssertFalse(limited.hit)
        XCTAssertEqual(limited.steps, 1)
        XCTAssertEqual(try Mandelbulb.march(origin: .zero, direction: SIMD3(1, 0, 0)).travel, 0)
        XCTAssertEqual(hit, try Mandelbulb.march(origin: origin, direction: SIMD3(0, 4, 0)))
    }
}
