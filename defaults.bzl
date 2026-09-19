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

"""Pinned versions of Chromium toolchain artifacts.

To update: check the CLANG_REVISION in a Chromium checkout at
tools/clang/scripts/update.py, the sysroot hashes in
build/linux/sysroot_scripts/sysroots.json and the libc++ revisions in DEPS.
"""

# Chromium Clang revision (from tools/clang/scripts/update.py).
CLANG_REVISION = "llvmorg-23-init-5669-g8a0be0bc"
CLANG_SUB_REVISION = 1
CLANG_VERSION = "%s-%s" % (CLANG_REVISION, CLANG_SUB_REVISION)

# LLVM major version (used for lib/clang/<version>/ path).
LLVM_MAJOR_VERSION = "23"

# GCS base URL for Chromium Clang tarballs.
_CLANG_BASE_URL = "https://commondatastorage.googleapis.com/chromium-browser-clang"

# Clang tarball URLs per host platform.
CLANG_URLS = {
    "linux-x86_64": ["%s/Linux_x64/clang-%s.tar.xz" % (_CLANG_BASE_URL, CLANG_VERSION)],
    # "darwin-x86_64": ["%s/Mac/clang-%s.tar.xz" % (_CLANG_BASE_URL, CLANG_VERSION)],
    # "darwin-aarch64": ["%s/Mac_arm64/clang-%s.tar.xz" % (_CLANG_BASE_URL, CLANG_VERSION)],
}

CLANG_SHA256 = {
    "linux-x86_64": "750b331006635281d7d90696629f67db748ba62004c46675eccb8af144141847",
}

# Coverage tools (llvm-cov + llvm-profdata) shipped as a separate package.
COVERAGE_TOOLS_URLS = {
    "linux-x86_64": ["%s/Linux_x64/llvm-code-coverage-%s.tar.xz" % (_CLANG_BASE_URL, CLANG_VERSION)],
}

COVERAGE_TOOLS_SHA256 = {
    "linux-x86_64": "8dcd816a83361b7924093ccba92dfe6bd29af2cf8af58bf7ce785b38c5027a8b",
}

# GCS base URL for Chromium Linux sysroots.
_SYSROOT_BASE_URL = "https://commondatastorage.googleapis.com/chrome-linux-sysroot"

# Sysroot URLs and hashes (from build/linux/sysroot_scripts/sysroots.json).
SYSROOT_URLS = {
    "linux-x86_64": ["%s/52d61d4446ffebfaa3dda2cd02da4ab4876ff237853f46d273e7f9b666652e1d" % _SYSROOT_BASE_URL],
    "linux-aarch64": ["%s/c7176a4c7aacbf46bda58a029f39f79a68008d3dee6518f154dcf5161a5486d8" % _SYSROOT_BASE_URL],
}

SYSROOT_SHA256 = {
    "linux-x86_64": "52d61d4446ffebfaa3dda2cd02da4ab4876ff237853f46d273e7f9b666652e1d",
    "linux-aarch64": "c7176a4c7aacbf46bda58a029f39f79a68008d3dee6518f154dcf5161a5486d8",
}

# libc++, libc++abi and llvm-libc revisions (from Chromium's DEPS:
# libcxx_revision, libcxxabi_revision, llvm_libc_revision). libc++ is built
# from source by this toolchain; see libcxx/libcxx_sources.bzl.
LIBCXX_REVISION = "97b436da4c33663581d394f4ee0a5977fc38c2f4"
LIBCXXABI_REVISION = "92767730c5f8350fc53f5b3de5c3c02d00bbab8c"
LLVM_LIBC_REVISION = "48db747a8d08f69b9f5330a5f49f21e2c491daae"

_LLVM_MIRROR = "https://chromium.googlesource.com/external/github.com/llvm/llvm-project"

def _llvm_subpath_archive(project, revision, subpath):
    return "%s/%s.git/+archive/%s/%s.tar.gz" % (_LLVM_MIRROR, project, revision, subpath)

# Source archives, keyed by destination directory in the sources repo. Only
# the directories the library build needs are fetched (llvm-libc provides
# the headers libc++'s from_chars/to_chars implementation includes).
LIBCXX_SOURCE_URLS = {
    "libcxx/include": [_llvm_subpath_archive("libcxx", LIBCXX_REVISION, "include")],
    "libcxx/src": [_llvm_subpath_archive("libcxx", LIBCXX_REVISION, "src")],
    "libcxx/vendor/llvm": [_llvm_subpath_archive("libcxx", LIBCXX_REVISION, "vendor/llvm")],
    "libcxxabi/include": [_llvm_subpath_archive("libcxxabi", LIBCXXABI_REVISION, "include")],
    "libcxxabi/src": [_llvm_subpath_archive("libcxxabi", LIBCXXABI_REVISION, "src")],
    "libc/hdr": [_llvm_subpath_archive("libc", LLVM_LIBC_REVISION, "hdr")],
    "libc/include": [_llvm_subpath_archive("libc", LLVM_LIBC_REVISION, "include")],
    "libc/shared": [_llvm_subpath_archive("libc", LLVM_LIBC_REVISION, "shared")],
    "libc/src/__support": [_llvm_subpath_archive("libc", LLVM_LIBC_REVISION, "src/__support")],
}

# Content pins: sha256 of each archive's canonical content blob (NOT of the
# tarball; gitiles tarballs are not byte-stable). libcxx/libcxx_sources.bzl
# documents the blob format and how to recompute a pin.
LIBCXX_SOURCE_SHA256 = {
    "libcxx/include": "c354776cb29fbdc4dbb2084fdb97bd4dcb47c0e5eabd56560a041ac9164b038e",
    "libcxx/src": "51016fc72c91194c6d90b1eeb074417d7d548efac7e73d2c032109fd1ee8c1f7",
    "libcxx/vendor/llvm": "98207a19093483d240a882964c08ae321ce4a1933c50e181d38118e010c965d9",
    "libcxxabi/include": "5228218bf8e9c13a67f2c517f67a8ab35e1c049df1f076b3b15db3fb50a3c778",
    "libcxxabi/src": "c59b09efc540b6b8755657d487744d6d99f3feaf86bcaf1fa4d663356c850b78",
    "libc/hdr": "d5f181c492d65de0de39cceb1a3ea95e8c211e432dc2af18431fdaf19c8bfcf1",
    "libc/include": "48d94ffb35ffea0ad1927ac7b620c500e4bd1a681a9a4c9ad389fc14993caeab",
    "libc/shared": "f52d81edefe4231da6696bd63cdf51f80cd17b11f7a4ecb4df009474a47b7e26",
    "libc/src/__support": "d49fe183a5bc5e61c9c43dab34650d7be362a5380d40d32e2df7cc586ef5d9e1",
}
