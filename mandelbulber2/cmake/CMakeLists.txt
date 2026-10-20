cmake_minimum_required(VERSION 3.24)

# Retain support for configuring this directory directly.
if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
    project(mandelbulber2 VERSION 2.35 LANGUAGES CXX)
endif()

include(GNUInstallDirs)
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/modules")
get_filename_component(MANDELBULBER_SOURCE_DIR "${CMAKE_CURRENT_LIST_DIR}/.." ABSOLUTE)

option(MANDELBULBER_ENABLE_OPENCL "Build the existing OpenCL renderer" ON)
option(MANDELBULBER_ENABLE_OPENMP "Enable parallel CPU mesh and voxel export" ON)
option(MANDELBULBER_ENABLE_EXR "Enable OpenEXR image output" ON)
option(MANDELBULBER_ENABLE_TIFF "Enable TIFF image output" ON)
option(MANDELBULBER_ENABLE_SNDFILE "Enable libsndfile audio input" ON)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
find_package(Qt6 6.7 REQUIRED COMPONENTS
    Core Gui Widgets UiTools Network Test Multimedia Qml Concurrent Svg QuickWidgets QuickControls2)
qt_standard_project_setup(REQUIRES 6.7)
find_package(PNG REQUIRED)
find_package(GSL REQUIRED)
find_package(LZO REQUIRED)
find_package(ZLIB REQUIRED)

# Generated formulas are added regularly; CONFIGURE_DEPENDS keeps regeneration automatic.
file(GLOB sources CONFIGURE_DEPENDS
    "${MANDELBULBER_SOURCE_DIR}/src/*.cpp"
    "${MANDELBULBER_SOURCE_DIR}/src/*.h"
    "${MANDELBULBER_SOURCE_DIR}/src/*.hpp"
    "${MANDELBULBER_SOURCE_DIR}/qt/*.cpp"
    "${MANDELBULBER_SOURCE_DIR}/qt/*.h"
    "${MANDELBULBER_SOURCE_DIR}/qt/*.hpp"
    "${MANDELBULBER_SOURCE_DIR}/formula/definition/*.cpp"
    "${MANDELBULBER_SOURCE_DIR}/formula/definition/*.h"
    "${MANDELBULBER_SOURCE_DIR}/formula/definition/*.hpp")

qt_add_executable(mandelbulber2 WIN32 MACOSX_BUNDLE
    ${sources} "${MANDELBULBER_SOURCE_DIR}/qt/icons.qrc")
set_target_properties(mandelbulber2 PROPERTIES
    AUTORCC ON
    AUTOUIC_SEARCH_PATHS "${MANDELBULBER_SOURCE_DIR}/qt"
    CXX_STANDARD 20 CXX_STANDARD_REQUIRED YES CXX_EXTENSIONS NO
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin")
target_include_directories(mandelbulber2 PRIVATE
    "${MANDELBULBER_SOURCE_DIR}" "${MANDELBULBER_SOURCE_DIR}/qt")
target_compile_definitions(mandelbulber2 PRIVATE QT_MESSAGELOGCONTEXT)
target_link_libraries(mandelbulber2 PRIVATE
    Qt6::Core Qt6::Gui Qt6::Widgets Qt6::UiTools Qt6::Network Qt6::Test
    Qt6::Multimedia Qt6::Qml Qt6::Concurrent Qt6::Svg Qt6::QuickWidgets Qt6::QuickControls2
    PNG::PNG GSL::gsl GSL::gslcblas LZO::LZO ZLIB::ZLIB)

set(render_controls_qml "${MANDELBULBER_SOURCE_DIR}/qml/Mandelbulber/Gui/RenderControls.qml")
set_source_files_properties("${render_controls_qml}" PROPERTIES QT_RESOURCE_ALIAS RenderControls.qml)
qt_add_qml_module(mandelbulber2
    URI Mandelbulber.Gui
    OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/Mandelbulber/Gui"
    QML_FILES "${render_controls_qml}")

if(MANDELBULBER_ENABLE_OPENCL)
    find_package(OpenCL REQUIRED)
    # The platform SDK supplies C headers; the Khronos C++ bindings are separate.
    find_path(OpenCL_CPP_INCLUDE_DIR
        NAMES CL/opencl.hpp CL/cl.hpp CL/cl2.hpp OpenCL/opencl.hpp OpenCL/cl.hpp
        HINTS ${OpenCL_INCLUDE_DIRS}
            /opt/homebrew/opt/opencl-clhpp-headers/include
            /usr/local/opt/opencl-clhpp-headers/include)
    if(NOT OpenCL_CPP_INCLUDE_DIR)
        message(FATAL_ERROR "OpenCL C++ headers are required; install OpenCL-CLHPP or configure -DMANDELBULBER_ENABLE_OPENCL=OFF")
    endif()
    target_include_directories(mandelbulber2 PRIVATE "${OpenCL_CPP_INCLUDE_DIR}")
    target_link_libraries(mandelbulber2 PRIVATE OpenCL::OpenCL)
    target_compile_definitions(mandelbulber2 PRIVATE USE_OPENCL=1)
endif()

if(MANDELBULBER_ENABLE_OPENMP)
    if(APPLE AND CMAKE_CXX_COMPILER_ID STREQUAL "AppleClang")
        find_path(MANDELBULBER_OMP_INCLUDE_DIR omp.h
            HINTS /opt/homebrew/opt/libomp/include /usr/local/opt/libomp/include)
        find_library(MANDELBULBER_OMP_LIBRARY omp
            HINTS /opt/homebrew/opt/libomp/lib /usr/local/opt/libomp/lib)
        if(MANDELBULBER_OMP_INCLUDE_DIR AND MANDELBULBER_OMP_LIBRARY)
            set(OpenMP_CXX_FLAGS "-Xpreprocessor -fopenmp")
            set(OpenMP_CXX_LIB_NAMES omp)
            set(OpenMP_omp_LIBRARY "${MANDELBULBER_OMP_LIBRARY}")
            set(OpenMP_CXX_INCLUDE_DIR "${MANDELBULBER_OMP_INCLUDE_DIR}")
        endif()
    endif()
    find_package(OpenMP REQUIRED COMPONENTS CXX)
    target_link_libraries(mandelbulber2 PRIVATE OpenMP::OpenMP_CXX)
endif()

if(MANDELBULBER_ENABLE_TIFF)
    find_package(TIFF REQUIRED)
    target_link_libraries(mandelbulber2 PRIVATE TIFF::TIFF)
    target_compile_definitions(mandelbulber2 PRIVATE USE_TIFF)
endif()

if(MANDELBULBER_ENABLE_EXR)
    find_package(OpenEXR CONFIG REQUIRED)
    target_link_libraries(mandelbulber2 PRIVATE OpenEXR::OpenEXR)
    target_compile_definitions(mandelbulber2 PRIVATE USE_EXR)
endif()

if(MANDELBULBER_ENABLE_SNDFILE)
    find_package(PkgConfig REQUIRED)
    pkg_check_modules(SNDFILE REQUIRED IMPORTED_TARGET sndfile)
    target_link_libraries(mandelbulber2 PRIVATE PkgConfig::SNDFILE)
    target_compile_definitions(mandelbulber2 PRIVATE USE_SNDFILE)
endif()

if(MSVC)
    target_compile_definitions(mandelbulber2 PRIVATE
        _CRT_SECURE_NO_WARNINGS _HAS_STD_BYTE=0 _USE_MATH_DEFINES)
endif()

if(APPLE)
    target_compile_definitions(mandelbulber2 PRIVATE SHARED_DIR_IS_APP_DIR=1)
    target_link_libraries(mandelbulber2 PRIVATE "-framework CoreFoundation")
    set(icon "${MANDELBULBER_SOURCE_DIR}/mac/mandelbulber2.icns")
    target_sources(mandelbulber2 PRIVATE "${icon}")
    set_source_files_properties("${icon}" PROPERTIES MACOSX_PACKAGE_LOCATION Resources)
    set_target_properties(mandelbulber2 PROPERTIES
        MACOSX_BUNDLE_GUI_IDENTIFIER com.mandelbulber.mandelbulber2
        MACOSX_BUNDLE_BUNDLE_VERSION "${PROJECT_VERSION}"
        MACOSX_BUNDLE_SHORT_VERSION_STRING "${PROJECT_VERSION}"
        MACOSX_BUNDLE_ICON_FILE mandelbulber2.icns)
    set(resource_destination "$<TARGET_BUNDLE_CONTENT_DIR:mandelbulber2>/Resources")
else()
    set(resource_destination "${CMAKE_BINARY_DIR}/share/mandelbulber2")
endif()

# Runtime-loaded assets can change without recompiling the executable.
add_custom_target(mandelbulber_resources
    COMMAND "${CMAKE_COMMAND}" -E make_directory "${resource_destination}"
    COMMAND "${CMAKE_COMMAND}" -E copy_directory
        "${MANDELBULBER_SOURCE_DIR}/deploy/share/mandelbulber2" "${resource_destination}"
    VERBATIM)
foreach(directory formula language opencl)
    add_custom_command(TARGET mandelbulber_resources POST_BUILD
        COMMAND "${CMAKE_COMMAND}" -E copy_directory
            "${MANDELBULBER_SOURCE_DIR}/${directory}" "${resource_destination}/${directory}"
        VERBATIM)
endforeach()
add_custom_command(TARGET mandelbulber_resources POST_BUILD
    COMMAND "${CMAKE_COMMAND}" -E copy_directory
        "${MANDELBULBER_SOURCE_DIR}/deploy/doc" "${resource_destination}/doc"
    COMMAND "${CMAKE_COMMAND}" -E copy_if_different
        "${MANDELBULBER_SOURCE_DIR}/deploy/NEWS" "${resource_destination}/doc/NEWS"
    VERBATIM)
add_dependencies(mandelbulber2 mandelbulber_resources)

if(BUILD_TESTING)
    add_test(NAME application_regression
        COMMAND $<TARGET_FILE:mandelbulber2> --test
            --logfilepath "${CMAKE_BINARY_DIR}/application-test-runtime.log")
    set_tests_properties(application_regression PROPERTIES
        WORKING_DIRECTORY "${resource_destination}" TIMEOUT 600)
endif()

install(TARGETS mandelbulber2
    BUNDLE DESTINATION . RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}")
if(NOT APPLE)
    install(DIRECTORY "${MANDELBULBER_SOURCE_DIR}/deploy/share/mandelbulber2/"
        DESTINATION "${CMAKE_INSTALL_DATADIR}/mandelbulber2")
    install(DIRECTORY "${MANDELBULBER_SOURCE_DIR}/formula"
        "${MANDELBULBER_SOURCE_DIR}/language" "${MANDELBULBER_SOURCE_DIR}/opencl"
        "${MANDELBULBER_SOURCE_DIR}/deploy/doc"
        DESTINATION "${CMAKE_INSTALL_DATADIR}/mandelbulber2")
    if(UNIX)
        install(FILES "${MANDELBULBER_SOURCE_DIR}/deploy/linux/mandelbulber2.desktop"
            DESTINATION "${CMAKE_INSTALL_DATADIR}/applications")
        install(FILES "${MANDELBULBER_SOURCE_DIR}/deploy/share/mandelbulber2/icons/mandelbulber.png"
            DESTINATION "${CMAKE_INSTALL_DATADIR}/icons/hicolor/256x256/apps"
            RENAME mandelbulber2.png)
    endif()
endif()
