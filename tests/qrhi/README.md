# QRhi Metal migration probe

Opt-in macOS hardware check, not an application renderer or OpenCL translator.
Requires Qt 6.7+ GUI private development headers and Shader Tools. The root build
must enable testing and `MANDELBULBER_BUILD_QRHI_TEST`.

Build `mandelbulber_qrhi_probe`, then run `ctest -R qrhi_metal_mandelbulb --output-on-failure`.
The test requires real Metal compute and storage-buffer readback; missing support
fails rather than silently substituting the null or CPU backend. It writes
`qrhi-mandelbulb.png` to the test working directory.

The shader ports the classic iteration from
`mandelbulber2/formula/opencl/mandelbulb.cl`, with logarithmic distance estimation
from `mandelbulber2/src/calculate_distance.cpp`. This bounded profile fixes power
8, zero angle offsets, 32 iterations, bailout radius 8, initial z = point, and
adds the point after every iteration. Points that do not escape return zero
distance. The zero-radius spherical singularity uses the limiting zero-power
output. These choices are explicit probe policy, not full scene compatibility.

One executable checks 12 escaped, interior, zero and near-zero points against an
independent scalar double reference, including escape flags and iteration counts.
Distance tolerance is `3e-4 + 1e-3 * abs(reference)`. A 64x64 raymarch additionally
checks finite bounded colors and a nonempty silhouette with background pixels.
This establishes a real formula compute/readback path, not scene parity or speed.

`qt_add_shaders` packages SPIR-V, GLSL 430/310es, HLSL 50 and MSL 12; Metal source
is compiled by QRhi at runtime. Build-time `--metallib` is deliberately unnecessary
for this first check. See the [QSB manual](https://doc.qt.io/qt-6/qtshadertools-qsb.html).
QRhi has limited compatibility guarantees; rebuild and rerun this check on Qt upgrades.
