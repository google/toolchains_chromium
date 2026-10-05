# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Build targets for the from-source libc++ runtime.

`libcxx_runtime_targets()` is called from the BUILD file that
libcxx_sources.bzl generates in the sources repo. It defines:

- `headers`: the libc++ and libc++abi headers (the toolchain's compiler_files).
- `static_runtime`: `libc++.a` + `libc++abi.a`, in link order, compiled so that
  the library is private to the object it is linked into (hidden visibility,
  no visibility annotations); only `operator new`/`delete` stay public so
  allocator replacement keeps working.
- `dynamic_runtime`: `libc++.so` with libc++abi linked in, compiled with the
  visibility annotations on, i.e. exporting the libc++ ABI surface.

The two runtimes are built by the toolchain itself in the "bootstrap"
configuration (see bootstrap.bzl), with the same compiler flags as the code
that will use them, except for the handful of library copts pinned below.
"""

load("@rules_cc//cc:defs.bzl", "cc_binary", "cc_library")
load("//libcxx:bootstrap.bzl", "bootstrapped_archives", "bootstrapped_shared_library")

# libcxx/src/CMakeLists.txt (LIBCXX_SOURCES) for Linux with threads, random
# device, localization and filesystem enabled, no compiler-rt builtins
# (int128_builtins.cpp), plus new.cpp (operator new/delete live in libc++, as
# in Chromium) and the sources of upstream's libc++experimental.a.
LIBCXX_SOURCES = [
    "algorithm.cpp",
    "any.cpp",
    "bind.cpp",
    "call_once.cpp",
    "charconv.cpp",
    "chrono.cpp",
    "error_category.cpp",
    "exception.cpp",
    "expected.cpp",
    "filesystem/filesystem_clock.cpp",
    "filesystem/filesystem_error.cpp",
    "filesystem/path.cpp",
    "functional.cpp",
    "hash.cpp",
    "memory.cpp",
    "memory_resource.cpp",
    "new_handler.cpp",
    "new_helpers.cpp",
    "optional.cpp",
    "print.cpp",
    "random_shuffle.cpp",
    "ryu/d2fixed.cpp",
    "ryu/d2s.cpp",
    "ryu/f2s.cpp",
    "stdexcept.cpp",
    "string.cpp",
    "system_error.cpp",
    "typeinfo.cpp",
    "valarray.cpp",
    "variant.cpp",
    "vector.cpp",
    "verbose_abort.cpp",
    # LIBCXX_ENABLE_THREADS
    "atomic.cpp",
    "barrier.cpp",
    "condition_variable_destructor.cpp",
    "condition_variable.cpp",
    "future.cpp",
    "mutex_destructor.cpp",
    "mutex.cpp",
    "shared_mutex.cpp",
    "thread.cpp",
    # LIBCXX_ENABLE_RANDOM_DEVICE
    "random.cpp",
    # LIBCXX_ENABLE_LOCALIZATION
    "fstream.cpp",
    "ios.cpp",
    "ios.instantiations.cpp",
    "iostream.cpp",
    "locale.cpp",
    "ostream.cpp",
    "regex.cpp",
    "strstream.cpp",
    "text_encoding.cpp",
    # LIBCXX_ENABLE_FILESYSTEM
    "filesystem/directory_entry.cpp",
    "filesystem/directory_iterator.cpp",
    "filesystem/operations.cpp",
    "filesystem/int128_builtins.cpp",
    # LIBCXX_ENABLE_NEW_DELETE_DEFINITIONS
    "new.cpp",
    # LIBCXX_EXPERIMENTAL_SOURCES
    "experimental/keep.cpp",
    "experimental/log_hardening_failure.cpp",
    "experimental/chrono_exception.cpp",
    "experimental/time_zone.cpp",
    "experimental/tzdb.cpp",
    "experimental/tzdb_list.cpp",
]

# libcxxabi/src/CMakeLists.txt (LIBCXXABI_SOURCES) for Linux with exceptions
# and threads; stdlib_new_delete.cpp is omitted because new.cpp above
# provides operator new/delete.
LIBCXXABI_SOURCES = [
    "cxa_aux_runtime.cpp",
    "cxa_default_handlers.cpp",
    "cxa_demangle.cpp",
    "cxa_exception_storage.cpp",
    "cxa_guard.cpp",
    "cxa_handlers.cpp",
    "cxa_vector.cpp",
    "cxa_virtual.cpp",
    "stdlib_exception.cpp",
    "stdlib_stdexcept.cpp",
    "stdlib_typeinfo.cpp",
    "abort_message.cpp",
    "fallback_malloc.cpp",
    "private_typeinfo.cpp",
    # LIBCXXABI_ENABLE_EXCEPTIONS
    "cxa_exception.cpp",
    "cxa_personality.cpp",
    # LIBCXXABI_ENABLE_THREADS (non-Apple UNIX)
    "cxa_thread_atexit.cpp",
]

# Flags every library TU gets, after the toolchain's and the user's flags
# (so they win): upstream requires C++26, exceptions and RTTI for the library
# regardless of what the client code is built with. The user's warning flags
# (--copt/--cxxopt, -Werror included) reach these TUs too, and warnings in
# the library sources are nothing the user can act on: -Wno-everything resets
# them all at this point of the command line (unlike -w, which would also
# disable the flag after it). -Wundef stays, as an error: a macro that is
# tested with #if but undefined means the configuration drifted from the
# sources (new or renamed _LIBCPP_* / LIBC_* macros), which must fail at the
# revision bump instead of silently evaluating to 0.
_LIBRARY_COPTS = [
    "-std=c++26",
    "-fexceptions",
    "-frtti",
    "-fPIC",
    "-fstrict-aliasing",
    "-fvisibility=hidden",
    "-fvisibility-inlines-hidden",
    "-nostdinc++",
    "-Wno-everything",
    "-Werror=undef",
    "-D_LIBCPP_BUILDING_LIBRARY",
    "-DLIBCXX_BUILDING_LIBCXXABI",
    # libc++abi guard variables use futexes directly instead of a global mutex.
    "-D_LIBCXXABI_USE_FUTEX",
    # Namespace of the llvm-libc helpers libc++ borrows for from_chars/to_chars.
    "-DLIBC_NAMESPACE=__llvm_libc_tc",
]

# Static archives: nothing is exported from the object the archive is linked
# into...
_STATIC_COPTS = _LIBRARY_COPTS + [
    "-D_LIBCPP_DISABLE_VISIBILITY_ANNOTATIONS=",
    "-D_LIBCXXABI_DISABLE_VISIBILITY_ANNOTATIONS",
]

# ...except the replaceable operator new/delete, defined by libc++ (new.cpp):
# they stay public so that a program's own definitions replace them in every
# linked object (ELF keeps the least visible form when merging symbols).
# copts are Bourne-shell tokenized by rules_cc, hence the escaped quotes.
_LIBCXX_STATIC_COPTS = _STATIC_COPTS + [
    "-D_LIBCPP_OVERRIDABLE_FUNC_VIS=__attribute__((__visibility__(\\\"default\\\")))",
]

# ubsan's vptr check calls __dynamic_cast, which private_typeinfo.cpp
# implements: never instrument libc++abi with it.
_LIBCXXABI_COPTS = ["-fno-sanitize=vptr"]

_INCLUDES = [
    "libcxx/include",
    "libcxxabi/include",
    # Library-internal headers (libc++abi includes some of libc++'s).
    "libcxx/src",
    # llvm-libc headers, included as "shared/...", "src/__support/...", ...
    "libc",
]

def libcxx_runtime_targets():
    """Declares the libc++ runtime targets in the sources repo."""
    native.filegroup(
        name = "headers",
        srcs = native.glob(["libcxx/include/**", "libcxxabi/include/**"]),
    )

    # Headers the library sources include besides the public ones.
    native.filegroup(
        name = "private_headers",
        srcs = native.glob(
            ["libcxx/src/**", "libcxxabi/src/**", "libc/**"],
            exclude = ["**/*.cpp"],
        ),
    )

    libcxx_srcs = ["libcxx/src/" + src for src in LIBCXX_SOURCES]
    libcxxabi_srcs = ["libcxxabi/src/" + src for src in LIBCXXABI_SOURCES]

    # Declared as textual headers: many are not .h files (<vector>, *.def).
    support = [":headers", ":private_headers"]

    cc_library(
        name = "c++",
        srcs = libcxx_srcs,
        textual_hdrs = support,
        copts = _LIBCXX_STATIC_COPTS,
        includes = _INCLUDES,
        linkstatic = True,
    )

    cc_library(
        name = "c++abi",
        srcs = libcxxabi_srcs,
        textual_hdrs = support,
        copts = _STATIC_COPTS + _LIBCXXABI_COPTS,
        includes = _INCLUDES,
        linkstatic = True,
    )

    # libc++.a first: it references libc++abi, not the other way round.
    bootstrapped_archives(
        name = "static_runtime",
        deps = [":c++", ":c++abi"],
    )

    # Separate object sets for the shared library: the visibility annotations
    # must stay on so the ABI surface is exported.
    cc_library(
        name = "c++_shared_objects",
        srcs = libcxx_srcs,
        textual_hdrs = support,
        copts = _LIBRARY_COPTS,
        includes = _INCLUDES,
        alwayslink = True,
        linkstatic = True,
        visibility = ["//visibility:private"],
    )

    cc_library(
        name = "c++abi_shared_objects",
        srcs = libcxxabi_srcs,
        textual_hdrs = support,
        copts = _LIBRARY_COPTS + _LIBCXXABI_COPTS,
        includes = _INCLUDES,
        alwayslink = True,
        linkstatic = True,
        visibility = ["//visibility:private"],
    )

    # Bazel links consumers with -l:libc++.so, which records the bare name as
    # DT_NEEDED on its own; the soname (Chromium's component build sets the
    # same one) covers consumers that pass the file by path.
    cc_binary(
        name = "libc++.so",
        linkshared = True,
        linkopts = ["-Wl,-soname,libc++.so"],
        deps = [
            ":c++_shared_objects",
            ":c++abi_shared_objects",
        ],
    )

    bootstrapped_shared_library(
        name = "dynamic_runtime",
        dep = ":libc++.so",
    )
