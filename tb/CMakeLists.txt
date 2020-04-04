cmake_minimum_required(VERSION 3.8)
project(hx4k_led_panel)

find_package(verilator HINTS $ENV{VERILATOR_ROOT} ${VERILATOR_ROOT})
if (NOT verilator_FOUND)
    message(FATAL_ERROR "Could not find Verilator. Install or set $VERILATOR_ROOT")
endif()

add_executable(flash_loader_tb flash_loader_tb.cpp)
verilate(flash_loader_tb COVERAGE TRACE
    INCLUDE_DIRS "${PROJECT_SOURCE_DIR}"
    VERILATOR_ARGS -O2 -x-assign 0
    SOURCES ${PROJECT_SOURCE_DIR}/../flash_loader.v
)

add_executable(panel_driver_tb panel_driver_tb.cpp)
verilate(panel_driver_tb COVERAGE TRACE
    INCLUDE_DIRS "${PROJECT_SOURCE_DIR}"
    VERILATOR_ARGS -O2 -x-assign 0
    SOURCES ${PROJECT_SOURCE_DIR}/../panel_driver.v
)
