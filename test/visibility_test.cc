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

// A cc_binary(linkshared = True) links in static mode, so it carries its own
// copy of libc++/libc++abi. Everything that comes out of libc++.a/libc++abi.a
// must stay private to the library; what the library's own translation
// units define follows their own (default) visibility, see docs/libcxx.md.

#include <dlfcn.h>

#include <cstdio>

int main(int argc, char** argv) {
    if (argc != 2) {
        std::fprintf(stderr, "usage: %s <shared library>\n", argv[0]);
        return 2;
    }
    void* handle = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
    if (handle == nullptr) {
        std::fprintf(stderr, "dlopen: %s\n", dlerror());
        return 1;
    }

    int failures = 0;
    auto expect = [&](const char* symbol, bool exported) {
        // dlsym on a RTLD_LOCAL handle searches the library and its own
        // dependencies only, not this program's libc++.
        bool found = dlsym(handle, symbol) != nullptr;
        if (found != exported) {
            ++failures;
            std::fprintf(stderr, "FAIL: %s is %sexported\n", symbol, found ? "" : "not ");
        }
    };
    // The library's own API.
    expect("shared_func", true);
    // operator new(size_t): replaceable, so public.
    expect("_Znwm", true);
    // std::__libcpp_verbose_abort(const char*, ...): the hardening failure
    // handler is meant to be overridable, so libc++ keeps it public (weak).
    expect("_ZNSt4__tc22__libcpp_verbose_abortEPKcz", true);
    // libc++abi stays private: __cxa_throw, std::runtime_error::runtime_error
    // (const char*), typeinfo for std::runtime_error. The latter two have the
    // same mangled names in every C++ runtime (not under std::__tc).
    expect("__cxa_throw", false);
    expect("_ZNSt13runtime_errorC1EPKc", false);
    expect("_ZTISt13runtime_error", false);
    // libc++.a stays private: std::string::__init(size_t, char), which
    // shared_func's std::string(100, 'x') calls (it is one of libc++'s
    // extern templates, so it is compiled into the archive, not inline).
    expect("_ZNSt4__tc12basic_stringIcNS_11char_traitsIcEENS_9allocatorIcEEE6__initEmc", false);
    return failures == 0 ? 0 : 1;
}
