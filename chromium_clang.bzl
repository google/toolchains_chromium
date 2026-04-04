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

"""Repository rule that downloads the Chromium Clang toolchain.

Chromium's Clang tarball layout differs from standard LLVM releases:
- No include/c++/v1/ (Chromium builds libc++ from source)
- Several tools missing (clang-cpp, llvm-profdata, llvm-cov, etc.)

This rule patches the download by creating stub scripts for missing
tools and an empty include/c++/v1/ directory. When coverage tool URLs
are provided, llvm-cov and llvm-profdata are downloaded from Chromium's
separate llvm-code-coverage package instead of being stubbed.
"""

_STUB_TOOLS = [
    "clang-cpp",
    "clang-format",
    "clang-tidy",
    "clangd",
    "llvm-as",
    "llvm-cov",
    "llvm-dwp",
    "llvm-objdump",
    "llvm-profdata",
    "llvm-ranlib",
]

_BUILD_FILE_TPL = Label("//:chromium_clang.BUILD.tpl.bzl")

def _chromium_clang_impl(rctx):
    rctx.download_and_extract(
        url = rctx.attr.urls,
        sha256 = rctx.attr.sha256,
        stripPrefix = rctx.attr.strip_prefix,
    )

    # Download coverage tools (llvm-cov, llvm-profdata) if URLs are provided.
    # These overlay into bin/, replacing what would otherwise be stub scripts.
    if rctx.attr.coverage_tools_urls:
        rctx.download_and_extract(
            url = rctx.attr.coverage_tools_urls,
            sha256 = rctx.attr.coverage_tools_sha256,
        )

    rctx.file("include/c++/v1/.keep", "")

    for tool in _STUB_TOOLS:
        path = "bin/" + tool
        if not rctx.path(path).exists:
            rctx.file(
                path,
                '#!/bin/sh\necho "error: {tool} is not included in the Chromium Clang package" >&2\nexit 1\n'.format(tool = tool),
                executable = True,
            )

    llvm_version = "0"
    lib_clang = rctx.path("lib/clang")
    if lib_clang.exists:
        for entry in lib_clang.readdir():
            name = entry.basename
            if name[0].isdigit():
                llvm_version = name
                break

    rctx.template("BUILD.bazel", _BUILD_FILE_TPL, {
        "%{llvm_version}": llvm_version,
    })

chromium_clang = repository_rule(
    implementation = _chromium_clang_impl,
    attrs = {
        "urls": attr.string_list(mandatory = True),
        "sha256": attr.string(default = ""),
        "strip_prefix": attr.string(default = ""),
        "coverage_tools_urls": attr.string_list(default = [], doc = "URLs for the llvm-code-coverage package (llvm-cov + llvm-profdata)."),
        "coverage_tools_sha256": attr.string(default = "", doc = "SHA256 of the coverage tools tarball."),
    },
)
