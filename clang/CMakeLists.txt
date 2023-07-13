# Example CMake config for X16 llvm-mos project
cmake_minimum_required(VERSION 3.18)
set(LLVM_MOS_PLATFORM cx16)
find_package(llvm-mos-sdk REQUIRED)
add_compile_options(-mcpu=mos65c02 -Os -Wall -Wextra -Wshadow -Wconversion -Wno-language-extension-token)

project(clang-examples)
add_executable(bitmap.prg bitmap.c)
add_executable(plasma.prg plasma.c)
add_executable(k_console_test.prg k_console_test.c)
add_executable(k_datetime_test.prg k_datetime_test.c)
add_executable(k_graph_test.prg k_graph_test.c)
add_executable(k_graph_line_test.prg k_graph_line_test.c)
