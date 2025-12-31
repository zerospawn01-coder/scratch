cmake_minimum_required(VERSION 3.15)
project(ea-aol-runtime VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Options
option(BUILD_SHARED_LIBS "Build shared libraries" ON)
option(BUILD_EXAMPLES "Build example programs" ON)
option(BUILD_TESTS "Build tests" OFF)

# Include directories
include_directories(${CMAKE_SOURCE_DIR}/include)

# Source files
set(RUNTIME_SOURCES
    src/ea_aol_runtime.cpp
)

# Library target
if(BUILD_SHARED_LIBS)
    add_library(ea_aol SHARED ${RUNTIME_SOURCES})
else()
    add_library(ea_aol STATIC ${RUNTIME_SOURCES})
endif()

# Set library properties
set_target_properties(ea_aol PROPERTIES
    VERSION ${PROJECT_VERSION}
    SOVERSION 0
    PUBLIC_HEADER ${CMAKE_SOURCE_DIR}/include/ea_aol.h
)

# Installation
install(TARGETS ea_aol
    LIBRARY DESTINATION lib
    ARCHIVE DESTINATION lib
    PUBLIC_HEADER DESTINATION include
)

# Examples
if(BUILD_EXAMPLES)
    add_subdirectory(examples)
endif()

# Tests
if(BUILD_TESTS)
    enable_testing()
    add_subdirectory(tests)
endif()

# Print configuration
message(STATUS "EA-AOL Runtime Configuration:")
message(STATUS "  Version: ${PROJECT_VERSION}")
message(STATUS "  Build type: ${CMAKE_BUILD_TYPE}")
message(STATUS "  Shared libs: ${BUILD_SHARED_LIBS}")
message(STATUS "  Examples: ${BUILD_EXAMPLES}")
message(STATUS "  Tests: ${BUILD_TESTS}")
