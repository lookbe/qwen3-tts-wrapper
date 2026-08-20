cmake_minimum_required(VERSION 3.14)
project(qwen3-wrapper LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(QWEN_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../qwentts.cpp")
set(QWEN_SRC_DIR "${QWEN_ROOT}/src")

# version.h: embed git commit hash into all binaries.
set(VERSION_OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/version.h")
add_custom_target(version ALL
    COMMAND "${CMAKE_COMMAND}" "-DSRC_DIR=${QWEN_ROOT}" "-DOUTPUT=${VERSION_OUTPUT}"
            -P "${QWEN_ROOT}/tools/version.cmake"
    BYPRODUCTS "${VERSION_OUTPUT}"
    COMMENT "Checking git version"
)

find_package(Threads REQUIRED)

if(MSVC)
    add_compile_definitions(_CRT_SECURE_NO_WARNINGS)
    add_compile_options($<$<COMPILE_LANGUAGE:C,CXX>:/utf-8>)
endif()

# Audio tokenizer tensor names can exceed default GGML_MAX_NAME of 64
add_compile_definitions(GGML_MAX_NAME=128)

# GGML configuration.
# Desktop (Windows/Linux, via build.bat) wants runtime backend dispatch:
# every backend built as its own DLL/.so, picked at load time. Apple builds
# (macOS/iOS/iOS Simulator, via build_xcframework.sh) need one self-contained
# dylib with nothing to sideload, so they skip GGML_BACKEND_DL /
# GGML_CPU_ALL_VARIANTS / GGML_VULKAN entirely and fall back to ggml's own
# APPLE defaults (Metal + Accelerate BLAS), linked in statically.
set(GGML_NATIVE OFF CACHE BOOL "" FORCE)
set(GGML_CCACHE OFF CACHE BOOL "" FORCE)

if(APPLE)
    option(GGML_CUDA "Build with CUDA support" OFF)
    option(GGML_VULKAN "Build with Vulkan support" OFF)
else()
    set(GGML_BACKEND_DL ON CACHE BOOL "Build ggml backends as dynamic libraries" FORCE)
    set(GGML_CPU_ALL_VARIANTS ON CACHE BOOL "" FORCE)

    # Enable common backends
    option(GGML_CUDA "Build with CUDA support" OFF)
    option(GGML_VULKAN "Build with Vulkan support" ON)
endif()

add_subdirectory("${QWEN_ROOT}/ggml" "${CMAKE_CURRENT_BINARY_DIR}/ggml")

# Wrapper DLL
add_library(qwen3 SHARED
    qwen3tts.cpp
    "${QWEN_SRC_DIR}/qwen.cpp"
    "${QWEN_SRC_DIR}/pipeline-tts.cpp"
    "${QWEN_SRC_DIR}/pipeline-codec.cpp"
)

# Export symbols
target_compile_definitions(qwen3 PRIVATE QWEN_BUILD)

target_include_directories(qwen3 PUBLIC
    "${QWEN_SRC_DIR}"
    "${QWEN_ROOT}"
    "${CMAKE_CURRENT_BINARY_DIR}"
)

target_include_directories(qwen3 SYSTEM PRIVATE
    "${QWEN_ROOT}/ggml/include"
)

target_link_libraries(qwen3 PRIVATE ggml Threads::Threads)
add_dependencies(qwen3 version)

# Add test executable
add_executable(test-qwen3 test.cpp)
target_link_libraries(test-qwen3 PRIVATE qwen3)

# Ensure all DLLs are in the same directory for easy testing
set_target_properties(qwen3 test-qwen3 PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin"
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin"
)

# Also copy ggml backends to the bin directory if they are built as modules
# (This is usually handled by GGML's own CMake, but we ensure it here)
foreach(backend cpu blas cuda metal vulkan sycl)
    if(TARGET ggml-${backend})
        set_target_properties(ggml-${backend} PROPERTIES
            RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin"
            LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin"
        )
    endif()
endforeach()
