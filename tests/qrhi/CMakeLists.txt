if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
    cmake_minimum_required(VERSION 3.24)
    project(MandelbulberQrhiProbe LANGUAGES CXX)
    include(CTest)
endif()

if(NOT APPLE)
    message(FATAL_ERROR "The QRhi migration probe currently requires macOS Metal")
endif()

find_package(Qt6 6.7 REQUIRED COMPONENTS Gui ShaderTools)
# Older Qt releases export GuiPrivate through Gui rather than a separate package.
if(NOT TARGET Qt6::GuiPrivate)
    find_package(Qt6 6.7 REQUIRED COMPONENTS GuiPrivate)
endif()
qt_add_executable(mandelbulber_qrhi_probe main.cpp)
target_compile_features(mandelbulber_qrhi_probe PRIVATE cxx_std_20)
target_link_libraries(mandelbulber_qrhi_probe PRIVATE Qt6::Gui Qt6::GuiPrivate)
qt_add_shaders(mandelbulber_qrhi_probe mandelbulb_compute
    PREFIX "/qrhi"
    GLSL "430,310es"
    HLSL 50
    MSL 12
    FILES mandelbulb.comp
)
add_test(NAME qrhi_metal_mandelbulb COMMAND mandelbulber_qrhi_probe)
set_tests_properties(qrhi_metal_mandelbulb PROPERTIES TIMEOUT 60)
