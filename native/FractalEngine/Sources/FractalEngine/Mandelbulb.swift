// Copyright (C) 2019–2020 Mandelbulber Team. Distributed under GPLv3.
// Derived from mandelbulber2/formula/definition/fractal_mandelbulb.cpp.
// See repository LICENSE and README.md for the fixed-profile reference policy.
import Foundation

public enum FractalError: Error, Equatable {
    case invalidPoint
    case invalidDirection
    case invalidMarchParameters
    case nonFiniteResult
}

public struct DistanceEstimate: Sendable, Equatable {
    public let distance: Double
    public let escaped: Bool
    public let iterations: Int
}

public struct RayMarchResult: Sendable, Equatable {
    public let hit: Bool
    public let travel: Double
    public let steps: Int
}

/// Classic Mandelbulb, power 8, zero angle offsets, 32 iterations, bailout 8.
public enum Mandelbulb {
    public static func estimate(at point: SIMD3<Double>) throws -> DistanceEstimate {
        guard valid(point) else { throw FractalError.invalidPoint }
        var z = point
        var derivative = 1.0
        for iteration in 0..<32 {
            let radius = length(z)
            if radius > 8 {
                let distance = 0.5 * radius * log(radius) / derivative
                guard distance.isFinite, distance >= 0 else { throw FractalError.nonFiniteResult }
                return DistanceEstimate(distance: distance, escaped: true, iterations: iteration)
            }
            // The spherical transform is undefined at zero; its limiting output is zero.
            if radius < 1e-20 {
                z = point
                derivative = 1
                continue
            }
            let latitude = asin(min(1, max(-1, z.z / radius)))
            let longitude = atan2(z.y, z.x)
            derivative = pow(radius, 7) * derivative * 8 + 1
            let magnitude = pow(radius, 8)
            z = magnitude * SIMD3(
                cos(8 * latitude) * cos(8 * longitude),
                cos(8 * latitude) * sin(8 * longitude),
                sin(8 * latitude)
            ) + point
            guard z.x.isFinite, z.y.isFinite, z.z.isFinite, derivative.isFinite else {
                throw FractalError.nonFiniteResult
            }
        }
        // Bounded non-escape is a provisional interior classification, not proof of membership.
        return DistanceEstimate(distance: 0, escaped: false, iterations: 32)
    }

    /// CPU preview ray. A DE threshold hit is approximate; no production shading is included.
    public static func march(
        origin: SIMD3<Double>, direction: SIMD3<Double>,
        maxSteps: Int = 128, maxDistance: Double = 7, tolerance: Double = 0.001
    ) throws -> RayMarchResult {
        guard valid(origin) else { throw FractalError.invalidPoint }
        guard valid(direction) else { throw FractalError.invalidDirection }
        let magnitude = length(direction)
        guard magnitude > 1e-12 else { throw FractalError.invalidDirection }
        guard (1...512).contains(maxSteps), maxDistance.isFinite,
              maxDistance > 0, maxDistance <= 10_000,
              tolerance.isFinite, tolerance >= 1e-9, tolerance <= 1 else {
            throw FractalError.invalidMarchParameters
        }
        let unitDirection = direction / magnitude
        var travel = 0.0
        for step in 1...maxSteps {
            let distance = try estimate(at: origin + unitDirection * travel).distance
            if distance < tolerance {
                return RayMarchResult(hit: true, travel: travel, steps: step)
            }
            let next = travel + distance * 0.7
            if next > maxDistance {
                return RayMarchResult(hit: false, travel: maxDistance, steps: step)
            }
            travel = next
        }
        return RayMarchResult(hit: false, travel: travel, steps: maxSteps)
    }

    private static func valid(_ point: SIMD3<Double>) -> Bool {
        // shortcut: bounded coordinates avoid overflow; expand only with numeric qualification.
        point.x.isFinite && point.y.isFinite && point.z.isFinite
            && abs(point.x) <= 1_000_000 && abs(point.y) <= 1_000_000 && abs(point.z) <= 1_000_000
    }

    private static func length(_ vector: SIMD3<Double>) -> Double {
        sqrt(vector.x * vector.x + vector.y * vector.y + vector.z * vector.z)
    }
}
