// Copyright (C) 2020 Mandelbulber Team. GPL-3.0-or-later; see mandelbulber2/COPYING at repository root.
#include <metal_stdlib>
using namespace metal;

// Port of formula/opencl/mandelbulb.cl and tests/qrhi/mandelbulb.comp.
// shortcut: fixed power 8, zero angles, 32 iterations; add scene parameters before scene import.
float3 estimate(float3 point) {
    float3 z = point;
    float derivative = 1.0;
    float radius = length(z);
    for (int iteration = 0; iteration < 32; ++iteration) {
        if (radius > 8.0)
            return float3(0.5 * radius * log(radius) / derivative, 1.0, float(iteration));
        if (radius < 1e-20) {
            z = point;
            derivative = 1.0;
        } else {
            float theta = asin(clamp(z.z / radius, -1.0f, 1.0f)) * 8.0;
            float phi = atan2(z.y, z.x) * 8.0;
            float radiusPower = pow(radius, 7.0f);
            derivative = radiusPower * derivative * 8.0 + 1.0;
            radiusPower *= radius;
            z = radiusPower * float3(cos(theta) * cos(phi), cos(theta) * sin(phi), sin(theta)) + point;
        }
        radius = length(z);
    }
    return float3(0.0, 0.0, 32.0);
}

kernel void samples(device const float4 *points [[buffer(0)]],
                    device float4 *results [[buffer(1)]], uint index [[thread_position_in_grid]]) {
    if (index < 12) results[index] = float4(estimate(points[index].xyz), 1.0);
}

kernel void preview(texture2d<float, access::write> image [[texture(0)]],
                    device float4 *results [[buffer(0)]], uint2 pixel [[thread_position_in_grid]]) {
    uint size = image.get_width();
    if (pixel.x >= size || pixel.y >= image.get_height()) return;
    float2 uv = (float2(pixel) + 0.5) / float(size) * 2.0 - 1.0;
    float3 origin(0.0, -3.5, 0.0);
    float3 direction = normalize(float3(uv.x * 0.65, 1.0, -uv.y * 0.65));
    float travel = 0.0, hit = 0.0;
    for (int step = 0; step < 128; ++step) {
        float distance = estimate(origin + direction * travel).x;
        if (!isfinite(distance)) {
            results[pixel.y * size + pixel.x] = float4(NAN);
            image.write(float4(1, 0, 1, 1), pixel);
            return;
        }
        if (distance < 0.001) { hit = 1.0; break; }
        travel += distance * 0.7;
        if (travel > 7.0) break;
    }
    float shade = hit * clamp(1.0 - travel / 7.0, 0.0, 1.0);
    float3 color = float3(shade, shade * 0.8, shade * 0.55);
    results[pixel.y * size + pixel.x] = float4(color, hit);
    image.write(float4(color, 1), pixel);
}
