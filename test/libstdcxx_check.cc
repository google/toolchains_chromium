// Copyright 2026 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// Built by //:libstdcxx_test with the stdlib = "libstdc++" toolchain (see
// MODULE.bazel): the sysroot's libstdc++ must be the standard library in use,
// with nothing of libc++ visible.

#include <cstdio>
#include <stdexcept>
#include <string>
#include <thread>

#ifndef __GLIBCXX__
#error "expected the sysroot's libstdc++"
#endif
#ifdef _LIBCPP_VERSION
#error "libc++ headers are visible to a libstdc++ toolchain"
#endif

int main() {
  // std::thread needs libpthread with the sysroot's glibc (2.31); without
  // it, GCC 10's libstdc++ throws "Enable multithreading to use std::thread".
  std::string s;
  std::thread([&s] { s = std::string(3, 'x'); }).join();
  try {
    throw std::runtime_error(s + "!");
  } catch (const std::runtime_error& e) {
    std::puts(e.what());
    return std::string(e.what()) == "xxx!" ? 0 : 1;
  }
  return 1;
}
