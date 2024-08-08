# Example CMake config for X16 llvm-mos project
cmake_minimum_required(VERSION 3.18)
set(LLVM_MOS_PLATFORM cx16)
find_package(llvm-mos-sdk REQUIRED)
project(clang-examples)

# Only needed if there are C++ source files
set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED YES)
set(CMAKE_CXX_EXTENSIONS YES)

# Let's set a rather loud warning level
set(CLANG_WARNINGS
    -Wall
    -Wextra # reasonable and standard
    -Wshadow # warn the user if a variable declaration shadows one from a parent context
    -Wnon-virtual-dtor # warn the user if a class with virtual functions has a non-virtual destructor. This helps
    # catch hard to track down memory errors
    -Wold-style-cast # warn for c-style casts
    -Wcast-align # warn for potential performance problem casts
    -Wunused # warn on anything being unused
    -Woverloaded-virtual # warn if you overload (not override) a virtual function
    -Wpedantic # warn if non-standard C++ is used
    -Wconversion # warn on type conversions that may lose data
    -Wsign-conversion # warn on sign conversions
    -Wnull-dereference # warn if a null dereference is detected
    -Wformat=2 # warn on security issues around functions that format output (ie printf)
    -Wimplicit-fallthrough # warn on statements that fallthrough without an explicit annotation
)
add_compile_options(-mcpu=mos65c02 -Os ${CLANG_WARNINGS})

add_executable(bitmap.prg bitmap.c)
add_executable(plasma.prg plasma.cpp)
add_executable(k_console_test.prg k_console_test.c)
add_executable(k_datetime_test.prg k_datetime_test.c)
add_executable(k_graph_test.prg k_graph_test.c)
add_executable(k_graph_line_test.prg k_graph_line_test.c)
# Add more targets here...

