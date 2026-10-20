cmake_minimum_required(VERSION 3.24)
project(mandelbulber2 VERSION 2.35 LANGUAGES CXX)

include(CTest)
option(MANDELBULBER_BUILD_QRHI_TEST "Build the experimental QRhi compute probe" OFF)

add_subdirectory(mandelbulber2/cmake)

if(BUILD_TESTING)
    add_subdirectory(tests/quick)
endif()

if(BUILD_TESTING AND MANDELBULBER_BUILD_QRHI_TEST)
    add_subdirectory(tests/qrhi)
endif()
