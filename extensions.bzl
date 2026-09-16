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

"""Module extension for the Chromium C++ toolchain.

Consuming teams use this to get Chromium's Clang + Debian sysroot
configured as a Bazel C++ toolchain with minimal boilerplate.
"""

load("//:chromium_clang.bzl", "chromium_clang")
load("//:chromium_sysroot.bzl", "chromium_sysroot")
load("//:chromium_toolchain.bzl", "chromium_toolchain")
load(
    "//:defaults.bzl",
    "CLANG_SHA256",
    "CLANG_URLS",
    "COVERAGE_TOOLS_SHA256",
    "COVERAGE_TOOLS_URLS",
    "LLVM_MAJOR_VERSION",
    "SYSROOT_SHA256",
    "SYSROOT_URLS",
)

def _chromium_impl(module_ctx):
    # Canonical repo name for this module, used so generated BUILD files
    # can load .bzl files back from toolchains_chromium.
    this_repo = Label("//:BUILD.bazel").repo_name

    # Extension repos are: @@{module}++{extension}+{repo}
    # The canonical name format is explicitly unstable
    # (https://github.com/bazelbuild/bazel/issues/23127) but there
    # is no stable API to avoid it
    # (https://github.com/bazelbuild/bazel/issues/19055).
    module_name = this_repo.removesuffix("+")
    ext_prefix = module_name + "++chromium+"

    for mod in module_ctx.modules:
        for tag in mod.tags.toolchain:
            if not module_ctx.is_dev_dependency(tag):
                fail(
                    "The 'chromium' extension in module '%s' must be used with " % mod.name +
                    "'dev_dependency = True' on both 'use_extension' and 'register_toolchains'.",
                )
            name = tag.name
            targets = tag.targets if tag.targets else ["linux-x86_64"]

            # Download Chromium Clang.
            clang_name = name + "_clang"
            clang_urls = tag.clang_urls if tag.clang_urls else CLANG_URLS.get("linux-x86_64", [])
            clang_sha256 = tag.clang_sha256 if tag.clang_sha256 else CLANG_SHA256.get("linux-x86_64", "")

            # Coverage tools (llvm-cov + llvm-profdata).
            if tag.coverage_tools:
                coverage_urls = tag.coverage_tools_urls if tag.coverage_tools_urls else COVERAGE_TOOLS_URLS.get("linux-x86_64", [])
                coverage_sha256 = tag.coverage_tools_sha256 if tag.coverage_tools_sha256 else COVERAGE_TOOLS_SHA256.get("linux-x86_64", "")
            else:
                coverage_urls = []
                coverage_sha256 = ""

            chromium_clang(
                name = clang_name,
                urls = clang_urls,
                sha256 = clang_sha256,
                coverage_tools_urls = coverage_urls,
                coverage_tools_sha256 = coverage_sha256,
            )

            # Download sysroots for each target.
            sysroot_repos = {}
            for target in targets:
                sysroot_name = name + "_sysroot_" + target.replace("-", "_")
                sysroot_urls = SYSROOT_URLS.get(target)
                sysroot_sha = SYSROOT_SHA256.get(target, "")

                if not sysroot_urls:
                    fail("No sysroot available for target: %s" % target)

                chromium_sysroot(
                    name = sysroot_name,
                    urls = sysroot_urls,
                    sha256 = sysroot_sha,
                )
                sysroot_repos[target] = ext_prefix + sysroot_name

            # Generate cc_toolchain + toolchain() targets.
            chromium_toolchain(
                name = name,
                clang_repo = ext_prefix + clang_name,
                sysroots = sysroot_repos,
                targets = targets,
                llvm_version = LLVM_MAJOR_VERSION,
                toolchains_chromium_repo = this_repo,
            )

chromium = module_extension(
    implementation = _chromium_impl,
    tag_classes = {
        "toolchain": tag_class(
            attrs = {
                "name": attr.string(
                    default = "chromium_toolchain",
                    doc = "Name for the generated toolchain repos.",
                ),
                "targets": attr.string_list(
                    doc = 'Target platforms. Default: ["linux-x86_64"].',
                ),
                "clang_urls": attr.string_list(
                    doc = "Override Clang download URLs.",
                ),
                "clang_sha256": attr.string(
                    doc = "Override Clang tarball sha256.",
                ),
                "coverage_tools": attr.bool(
                    default = True,
                    doc = "Download llvm-cov and llvm-profdata for hermetic coverage.",
                ),
                "coverage_tools_urls": attr.string_list(
                    doc = "Override coverage tools download URLs (must match Clang version).",
                ),
                "coverage_tools_sha256": attr.string(
                    doc = "Override coverage tools tarball sha256.",
                ),
            },
        ),
    },
)
