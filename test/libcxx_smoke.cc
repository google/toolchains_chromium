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

// Smoke test for the from-source libc++: exercises the parts that need the
// compiled library, not just the headers (iostream, locale, exceptions and
// RTTI via libc++abi, threads, filesystem, regex, format/print, from_chars
// for floating point via the llvm-libc shared code, pmr, expected, chrono).

#include <charconv>
#include <chrono>
#include <cstdio>
#include <exception>
#include <expected>
#include <filesystem>
#include <format>
#include <iostream>
#include <memory_resource>
#include <mutex>
#include <print>
#include <regex>
#include <stdexcept>
#include <string>
#include <string_view>
#include <thread>
#include <typeinfo>
#include <variant>
#include <vector>

#ifndef _LIBCPP_VERSION
#error "expected libc++"
#endif
#ifdef __GLIBCXX__
#error "libstdc++ headers leaked into the include path"
#endif

#define STRINGIFY_(x) #x
#define STRINGIFY(x) STRINGIFY_(x)

// The configuration this toolchain renders into __config_site.
static_assert(_LIBCPP_ABI_VERSION == 2);
static_assert(std::string_view(STRINGIFY(_LIBCPP_ABI_NAMESPACE)) == "__tc");
static_assert(_LIBCPP_HARDENING_MODE == _LIBCPP_HARDENING_MODE_EXTENSIVE);

namespace {

struct Base {
    virtual ~Base() = default;
};
struct Derived : Base {};

int checks = 0;
int failures = 0;

void check(bool ok, const char* what) {
    ++checks;
    if (!ok) {
        ++failures;
        std::println(stderr, "FAIL: {}", what);
    }
}

}  // namespace

int main() {
    std::cout << "_LIBCPP_VERSION=" << _LIBCPP_VERSION << " __cplusplus=" << __cplusplus << std::endl;

    // Exceptions and RTTI (libc++abi).
    try {
        throw std::runtime_error("boom");
    } catch (const std::exception& e) {
        check(std::string(e.what()) == "boom", "exception what()");
    }
    Base* b = new Derived;
    check(dynamic_cast<Derived*>(b) != nullptr, "dynamic_cast");
    check(std::string(typeid(*b).name()).find("Derived") != std::string::npos, "typeid");
    delete b;

    // Threads and mutexes (thread.cpp, mutex.cpp).
    std::mutex m;
    int counter = 0;
    {
        std::vector<std::thread> threads;
        for (int i = 0; i < 4; ++i) {
            threads.emplace_back([&] {
                std::lock_guard<std::mutex> lock(m);
                ++counter;
            });
        }
        for (auto& t : threads) t.join();
    }
    check(counter == 4, "threads");

    // format / print (print.cpp, ostream.cpp).
    std::string s = std::format("{}-{:.2f}-{:>4}", 42, 3.14159, "x");
    check(s == "42-3.14-   x", "std::format");
    std::println("println: {}", s);

    // from_chars<double> (llvm-libc shared/str_to_float.h).
    double d = 0;
    const char* txt = "2.5e3";
    auto from = std::from_chars(txt, txt + 5, d);
    check(from.ec == std::errc() && d == 2500.0, "from_chars<double>");

    // to_chars<double> (ryu).
    char buf[64];
    auto to = std::to_chars(buf, buf + sizeof buf, 0.1);
    check(std::string(buf, to.ptr) == "0.1", "to_chars<double>");

    // filesystem (filesystem/*.cpp).
    std::error_code ec;
    auto tmp = std::filesystem::temp_directory_path(ec);
    check(!ec && std::filesystem::exists(tmp), "filesystem");

    // regex and locale (regex.cpp, locale.cpp).
    check(std::regex_match("abc123", std::regex("[a-z]+\\d+")), "regex");

    // pmr (memory_resource.cpp).
    std::pmr::monotonic_buffer_resource pool(1024);
    std::pmr::vector<int> pv(&pool);
    pv.push_back(7);
    check(pv[0] == 7, "pmr");

    // expected (expected.cpp).
    std::expected<int, std::string> e = std::unexpected(std::string("err"));
    try {
        (void)e.value();
        check(false, "expected should throw");
    } catch (const std::bad_expected_access<std::string>& ex) {
        check(ex.error() == "err", "bad_expected_access");
    }

    // chrono (chrono.cpp).
    auto now = std::chrono::system_clock::now();
    check(std::format("{:%Y}", now).size() == 4, "chrono format");

    // variant (variant.cpp).
    std::variant<int, std::string> v = 1;
    try {
        (void)std::get<std::string>(v);
        check(false, "bad_variant_access");
    } catch (const std::bad_variant_access&) {
        check(true, "bad_variant_access");
    }

    std::println("{} checks, {} failures", checks, failures);
    return failures == 0 ? 0 : 1;
}
