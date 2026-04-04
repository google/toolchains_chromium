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
tools/clang/scripts/update.py and the sysroot hashes in
build/linux/sysroot_scripts/sysroots.json.
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
