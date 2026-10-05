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

"""Repository rule that generates cc_toolchain targets for Chromium Clang."""

load("//:cc_toolchain_config.bzl", "TOOL_PATHS")

# Derive the symlink list from TOOL_PATHS, plus clang++ which has no
# dedicated tool role but is needed for C++ compilation.
_TOOL_BINARIES = sorted({p.removeprefix("bin/"): True for _, p in TOOL_PATHS}.keys() + ["clang++"])

def _chromium_toolchain_impl(rctx):
    clang_repo = rctx.attr.clang_repo

    # Symlink Clang binaries into this repo so tool_paths (which are relative
    # to the config package) resolve correctly. Using Label() triggers fetching
    # the clang repo first and creates absolute symlinks that Bazel can track
    # as proper inputs — more robust than wrapper scripts on RBE/sandboxfs.
    for tool in _TOOL_BINARIES:
        rctx.symlink(
            Label("@@{}//:bin/{}".format(clang_repo, tool)),
            "bin/" + tool,
        )

    # Generate a minimal BUILD file that delegates to the macro.
    sysroots_str = ", ".join([
        '"{}": "@@{}//sysroot:sysroot"'.format(k, v)
        for k, v in rctx.attr.sysroots.items()
    ])
    targets_str = ", ".join(['"{}"'.format(t) for t in rctx.attr.targets])
    libcxx_label = "@@" + rctx.attr.libcxx_repo if rctx.attr.libcxx_repo else ""

    rctx.file("BUILD.bazel", """\
load("@@{module}//:chromium_toolchain_targets.bzl", "chromium_toolchain_targets")

chromium_toolchain_targets(
    clang_label = "@@{clang_repo}",
    sysroots = {{{sysroots}}},
    targets = [{targets}],
    llvm_version = "{llvm_version}",
    libcxx_label = "{libcxx_label}",
)
""".format(
        module = rctx.attr.toolchains_chromium_repo,
        clang_repo = clang_repo,
        sysroots = sysroots_str,
        targets = targets_str,
        llvm_version = rctx.attr.llvm_version,
        libcxx_label = libcxx_label,
    ))

chromium_toolchain = repository_rule(
    implementation = _chromium_toolchain_impl,
    attrs = {
        "clang_repo": attr.string(mandatory = True, doc = "Canonical repo name of the Clang download."),
        "sysroots": attr.string_dict(mandatory = True, doc = "Map of target key to canonical sysroot repo name."),
        "targets": attr.string_list(mandatory = True, doc = "Target platform keys (e.g. linux-x86_64)."),
        "llvm_version": attr.string(mandatory = True),
        "libcxx_repo": attr.string(
            default = "",
            doc = "Canonical repo name of the libc++ sources (see libcxx/libcxx_sources.bzl); empty to use the sysroot's libstdc++.",
        ),
        "toolchains_chromium_repo": attr.string(mandatory = True, doc = "Canonical repo name of toolchains_chromium."),
    },
)
