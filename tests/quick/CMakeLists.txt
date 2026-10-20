if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
    cmake_minimum_required(VERSION 3.24)
    project(MandelbulberQuickTests LANGUAGES CXX)
    include(CTest)
endif()

find_package(Qt6 6.7 REQUIRED COMPONENTS QuickTest QuickControls2 QuickWidgets Test)
qt_standard_project_setup(REQUIRES 6.7)
qt_add_executable(mandelbulber_quick_tests main.cpp)
target_link_libraries(mandelbulber_quick_tests PRIVATE Qt6::QuickTest Qt6::QuickControls2)
target_compile_definitions(mandelbulber_quick_tests PRIVATE
    QUICK_TEST_SOURCE_DIR="${CMAKE_CURRENT_SOURCE_DIR}")
add_test(NAME quick_render_controls COMMAND mandelbulber_quick_tests)
set_tests_properties(quick_render_controls PROPERTIES
    ENVIRONMENT "QT_QPA_PLATFORM=offscreen;QT_QUICK_BACKEND=software;QT_QUICK_CONTROLS_STYLE=Basic"
    TIMEOUT 30)

set(gui_source_dir "${CMAKE_CURRENT_SOURCE_DIR}/../../mandelbulber2")
target_sources(mandelbulber_quick_tests PRIVATE "${gui_source_dir}/qt/icons.qrc")
set_target_properties(mandelbulber_quick_tests PROPERTIES AUTORCC ON)
qt_add_executable(mandelbulber_quick_widget_tests
    tst_render_controls_widget.cpp
    "${gui_source_dir}/qt/icons.qrc"
    "${gui_source_dir}/qt/render_controls.cpp"
    "${gui_source_dir}/qt/render_controls.h")
set_target_properties(mandelbulber_quick_widget_tests PROPERTIES AUTOMOC ON AUTORCC ON)
target_include_directories(mandelbulber_quick_widget_tests PRIVATE "${gui_source_dir}/qt")
target_link_libraries(mandelbulber_quick_widget_tests PRIVATE
    Qt6::QuickWidgets Qt6::QuickControls2 Qt6::Test)
set(render_controls_qml "${gui_source_dir}/qml/Mandelbulber/Gui/RenderControls.qml")
set_source_files_properties("${render_controls_qml}" PROPERTIES
    QT_RESOURCE_ALIAS RenderControls.qml)
qt_add_qml_module(mandelbulber_quick_widget_tests
    URI Mandelbulber.Gui
    OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/Mandelbulber/Gui"
    QML_FILES "${render_controls_qml}")
add_test(NAME quick_render_controls_widget COMMAND mandelbulber_quick_widget_tests)
set_tests_properties(quick_render_controls_widget PROPERTIES
    ENVIRONMENT "QT_QPA_PLATFORM=offscreen;QT_QUICK_BACKEND=software;QT_QUICK_CONTROLS_STYLE=Basic"
    TIMEOUT 30)
