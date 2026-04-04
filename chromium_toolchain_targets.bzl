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

"""Macro that declares cc_toolchain + toolchain() targets for Chromium Clang."""

load("@rules_cc//cc:defs.bzl", "cc_toolchain")
load("//:cc_toolchain_config.bzl", "chromium_cc_toolchain_config")

_TARGET_INFO = {
    "linux-x86_64": struct(
        triple = "x86_64-unknown-linux-gnu",
        cpu = "x86_64",
        os_constraint = "@platforms//os:linux",
        cpu_constraint = "@platforms//cpu:x86_64",
    ),
}

def chromium_toolchain_targets(clang_label, sysroots, targets, llvm_version):
    """Generates cc_toolchain and toolchain targets for each platform.

    Args:
        clang_label: Canonical label prefix for the Clang repo (e.g. "@@repo").
        sysroots: Dict of target key to canonical sysroot label string.
        targets: List of target platform keys (e.g. ["linux-x86_64"]).
        llvm_version: LLVM major version string.
    """
    local_tools = native.glob(["bin/*"])

    for target_key in targets:
        info = _TARGET_INFO[target_key]
        suffix = target_key.replace("-", "_")
        arch_triple = info.triple.replace("-unknown", "")
        clang_base = clang_label.removeprefix("@@")

        chromium_cc_toolchain_config(
            name = "config_" + suffix,
            target_system_name = info.triple,
            target_cpu = info.cpu,
            toolchain_identifier = "chromium_clang_" + suffix,
            sysroot_path = "external/{}/sysroot".format(sysroots[target_key].removeprefix("@@").split("//")[0]),
            resource_dir = "external/{}/lib/clang/{}".format(clang_base, llvm_version),
            cxx_builtin_include_directories = [
                "external/{}/lib/clang/{}/include".format(clang_base, llvm_version),
                "%sysroot%/usr/include",
                "%sysroot%/usr/include/" + arch_triple,
            ],
        )

        native.filegroup(
            name = "all_files_" + suffix,
            srcs = local_tools + [
                clang_label + "//:bin",
                clang_label + "//:include",
                clang_label + "//:lib",
                sysroots[target_key],
            ],
        )

        native.filegroup(
            name = "compiler_files_" + suffix,
            srcs = local_tools + [
                clang_label + "//:clang",
                clang_label + "//:include",
                sysroots[target_key],
            ],
        )

        native.filegroup(
            name = "linker_files_" + suffix,
            srcs = local_tools + [
                clang_label + "//:clang",
                clang_label + "//:ld",
                clang_label + "//:lib",
                clang_label + "//:ar",
                sysroots[target_key],
            ],
        )

        native.filegroup(
            name = "ar_files_" + suffix,
            srcs = local_tools + [clang_label + "//:ar"],
        )

        native.filegroup(
            name = "as_files_" + suffix,
            srcs = local_tools + [clang_label + "//:clang"],
        )

        native.filegroup(
            name = "dwp_files_" + suffix,
            srcs = local_tools + [clang_label + "//:dwp"],
        )

        native.filegroup(
            name = "objcopy_files_" + suffix,
            srcs = local_tools + [clang_label + "//:objcopy"],
        )

        native.filegroup(
            name = "strip_files_" + suffix,
            srcs = local_tools + [clang_label + "//:strip"],
        )

        native.filegroup(
            name = "coverage_files_" + suffix,
            srcs = local_tools + [
                clang_label + "//:clang",
                clang_label + "//:coverage_tools",
            ],
        )

        cc_toolchain(
            name = "cc_toolchain_" + suffix,
            toolchain_config = ":config_" + suffix,
            all_files = ":all_files_" + suffix,
            compiler_files = ":compiler_files_" + suffix,
            linker_files = ":linker_files_" + suffix,
            ar_files = ":ar_files_" + suffix,
            as_files = ":as_files_" + suffix,
            dwp_files = ":dwp_files_" + suffix,
            objcopy_files = ":objcopy_files_" + suffix,
            strip_files = ":strip_files_" + suffix,
            coverage_files = ":coverage_files_" + suffix,
        )

        native.toolchain(
            name = "cc_toolchain_{}_def".format(suffix),
            toolchain = ":cc_toolchain_" + suffix,
            toolchain_type = "@rules_cc//cc:toolchain_type",
            exec_compatible_with = [info.os_constraint, info.cpu_constraint],
            target_compatible_with = [info.os_constraint, info.cpu_constraint],
        )
