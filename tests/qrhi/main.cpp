#include <QFile>
#include <QGuiApplication>
#include <QImage>
#include <QDebug>
#include <rhi/qrhi.h>

#include <algorithm>
#include <array>
#include <cmath>
#include <cstring>
#include <memory>
#include <stdexcept>

namespace {
constexpr int sampleCount = 12;
constexpr int imageSize = 64;
struct Float4 { float x, y, z, w; };
static_assert(sizeof(Float4) == 16, "std430 vec4 stride");

void require(bool condition, const char *message)
{
    if (!condition)
        throw std::runtime_error(message);
}

// Independent scalar double reference for the bounded classic power-8 formula.
std::array<double, 3> reference(const Float4 &point)
{
    double x = point.x, y = point.y, z = point.z, derivative = 1.0;
    for (int iteration = 0; iteration < 32; ++iteration) {
        const double radius = std::sqrt(x * x + y * y + z * z);
        if (radius > 8.0)
            return {0.5 * radius * std::log(radius) / derivative, 1.0, double(iteration)};
        if (radius < 1e-20) {
            x = point.x; y = point.y; z = point.z;
            derivative = 1.0;
            continue;
        }
        const double latitude = std::asin(std::clamp(z / radius, -1.0, 1.0));
        const double longitude = std::atan2(y, x);
        derivative = std::pow(radius, 7.0) * derivative * 8.0 + 1.0;
        const double magnitude = std::pow(radius, 8.0);
        x = magnitude * std::cos(8.0 * latitude) * std::cos(8.0 * longitude) + point.x;
        y = magnitude * std::cos(8.0 * latitude) * std::sin(8.0 * longitude) + point.y;
        z = magnitude * std::sin(8.0 * latitude) + point.z;
    }
    return {0.0, 0.0, 32.0};
}
}

int main(int argc, char **argv)
{
    QGuiApplication app(argc, argv);
    try {
        const std::array<Float4, sampleCount> points = {{
            {2.0f, 0.3f, 0.2f, 0}, {-2.0f, 0.4f, -0.3f, 0},
            {0.3f, 2.0f, 0.7f, 0}, {0.3f, -0.4f, 2.0f, 0},
            {1.2f, 0.3f, 0.2f, 0}, {-1.2f, 0.3f, 0.2f, 0},
            {0.0f, 0.0f, 0.0f, 0}, {1e-22f, -1e-22f, 1e-22f, 0},
            {1e-6f, -2e-6f, 1e-6f, 0}, {0.1f, 0.1f, 0.1f, 0},
            {-0.2f, 0.15f, 0.1f, 0}, {9.0f, 0.0f, 0.0f, 0}
        }};
        QRhiMetalInitParams params;
        std::unique_ptr<QRhi> rhi(QRhi::create(QRhi::Metal, &params));
        require(bool(rhi), "Metal initialization failed (no CPU/null fallback permitted)");
        require(rhi->isFeatureSupported(QRhi::Compute), "Metal compute unavailable");
        require(rhi->isFeatureSupported(QRhi::ReadBackNonUniformBuffer), "Storage buffer readback unavailable");
        qInfo() << "Backend:" << rhi->backendName() << rhi->driverInfo();

        constexpr int resultCount = sampleCount + imageSize * imageSize;
        constexpr int resultBytes = resultCount * sizeof(Float4);
        std::unique_ptr<QRhiBuffer> input(rhi->newBuffer(QRhiBuffer::Immutable,
            QRhiBuffer::StorageBuffer, sizeof(points)));
        std::unique_ptr<QRhiBuffer> output(rhi->newBuffer(QRhiBuffer::Static,
            QRhiBuffer::StorageBuffer, resultBytes));
        require(input->create() && output->create(), "Storage buffer creation failed");
        std::unique_ptr<QRhiShaderResourceBindings> bindings(rhi->newShaderResourceBindings());
        bindings->setBindings({
            QRhiShaderResourceBinding::bufferLoad(0, QRhiShaderResourceBinding::ComputeStage, input.get()),
            QRhiShaderResourceBinding::bufferStore(1, QRhiShaderResourceBinding::ComputeStage, output.get())
        });
        require(bindings->create(), "Compute bindings creation failed");
        QFile shaderFile(QStringLiteral(":/qrhi/mandelbulb.comp.qsb"));
        require(shaderFile.open(QIODevice::ReadOnly), "Embedded QSB package missing");
        const QShader shader = QShader::fromSerialized(shaderFile.readAll());
        require(shader.isValid(), "Invalid QSB package");
        bool hasMsl = false;
        for (const auto &key : shader.availableShaders())
            hasMsl |= key.source() == QShader::MslShader;
        require(hasMsl, "QSB package has no Metal shader");
        std::unique_ptr<QRhiComputePipeline> pipeline(rhi->newComputePipeline());
        pipeline->setShaderStage({QRhiShaderStage::Compute, shader});
        pipeline->setShaderResourceBindings(bindings.get());
        require(pipeline->create(), "Metal compute pipeline compilation failed");

        QRhiCommandBuffer *commands = nullptr;
        require(rhi->beginOffscreenFrame(&commands) == QRhi::FrameOpSuccess, "Offscreen frame failed");
        auto *upload = rhi->nextResourceUpdateBatch();
        upload->uploadStaticBuffer(input.get(), points.data());
        commands->beginComputePass(upload);
        commands->setComputePipeline(pipeline.get());
        commands->setShaderResources(bindings.get());
        commands->dispatch((resultCount + 63) / 64, 1, 1);
        QRhiReadbackResult readback;
        bool completed = false;
        readback.completed = [&completed] { completed = true; };
        auto *download = rhi->nextResourceUpdateBatch();
        download->readBackBuffer(output.get(), 0, resultBytes, &readback);
        commands->endComputePass(download);
        require(rhi->endOffscreenFrame() == QRhi::FrameOpSuccess, "Metal submission failed");
        require(completed && readback.data.size() == resultBytes, "Incomplete GPU readback");
        std::array<Float4, resultCount> results;
        std::memcpy(results.data(), readback.data.constData(), resultBytes);

        double maxError = 0.0;
        for (int i = 0; i < sampleCount; ++i) {
            const auto expected = reference(points[i]);
            const auto actual = results[i];
            const double error = std::abs(actual.x - expected[0]);
            maxError = std::max(maxError, error);
            if (!std::isfinite(actual.x) || error > 3e-4 + 1e-3 * std::abs(expected[0])
                || actual.y != expected[1] || actual.z != expected[2]) {
                qCritical() << "DE sample" << i << "GPU" << actual.x << actual.y << actual.z
                            << "CPU" << expected[0] << expected[1] << expected[2];
                throw std::runtime_error("GPU distance estimate disagrees with double reference");
            }
        }

        QImage image(imageSize, imageSize, QImage::Format_RGB32);
        int hits = 0;
        for (int pixel = 0; pixel < imageSize * imageSize; ++pixel) {
            const auto color = results[sampleCount + pixel];
            require(std::isfinite(color.x) && std::isfinite(color.y) && std::isfinite(color.z)
                && (color.w == 0.0f || color.w == 1.0f), "Non-finite or invalid raymarch pixel");
            require(color.x >= 0 && color.x <= 1 && color.y >= 0 && color.y <= 1
                && color.z >= 0 && color.z <= 1, "Raymarch color outside expected range");
            hits += int(color.w);
            image.setPixel(pixel % imageSize, pixel / imageSize,
                qRgb(int(color.x * 255), int(color.y * 255), int(color.z * 255)));
        }
        require(hits > 0 && hits < imageSize * imageSize, "Raymarch silhouette empty or fills image");
        require(image.save(QStringLiteral("qrhi-mandelbulb.png")), "Cannot save probe image");
        qInfo() << "PASS:" << sampleCount << "DE samples; max absolute error" << maxError
                << "; raymarch hits" << hits << "; output qrhi-mandelbulb.png";
        return 0;
    } catch (const std::exception &error) {
        qCritical() << error.what();
        return 1;
    }
}
