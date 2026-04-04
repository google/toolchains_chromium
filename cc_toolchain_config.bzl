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

"""C++ toolchain configuration for Chromium Clang."""

load(
    "@rules_cc//cc:action_names.bzl",
    "ACTION_NAMES",
    "ACTION_NAME_GROUPS",
)
load(
    "@rules_cc//cc:cc_toolchain_config_lib.bzl",
    "feature",
    "flag_group",
    "flag_set",
    "tool_path",
    "variable_with_value",
    "with_feature_set",
)
load("@rules_cc//cc:defs.bzl", "CcToolchainConfigInfo", "cc_common")

# Mapping from Bazel tool role to binary path (relative to the toolchain
# repo root). chromium_toolchain.bzl loads this to derive the symlink list.
TOOL_PATHS = [
    ("gcc", "bin/clang"),
    ("ld", "bin/ld.lld"),
    ("ar", "bin/llvm-ar"),
    ("cpp", "bin/clang-cpp"),
    ("nm", "bin/llvm-nm"),
    ("objcopy", "bin/llvm-objcopy"),
    ("objdump", "bin/llvm-objdump"),
    ("strip", "bin/llvm-strip"),
    ("gcov", "bin/llvm-profdata"),
    ("llvm-cov", "bin/llvm-cov"),
    ("dwp", "bin/llvm-dwp"),
]

def _impl(ctx):
    # tool_paths are relative to the config target's package. The toolchain
    # repo rule symlinks Clang binaries into bin/ so paths resolve correctly.
    tool_path_list = [tool_path(name = n, path = p) for n, p in TOOL_PATHS]

    target = ctx.attr.target_system_name
    all_compile = ACTION_NAME_GROUPS.all_cc_compile_actions
    all_link = ACTION_NAME_GROUPS.all_cc_link_actions

    # C/C++ compile actions only (excludes assemble/preprocess-assemble).
    # Used for coverage flags that are meaningless for assembly.
    cc_compile = ACTION_NAME_GROUPS.all_cpp_compile_actions + [ACTION_NAMES.c_compile]

    # Clang finds its resource dir (builtins like stddef.h, sanitizer
    # runtimes) relative to the binary. Since we symlink the binary into
    # a different repo, we must tell Clang explicitly where its resources
    # are — for both compilation (headers) and linking (runtime libs).
    resource_dir_feature = []
    if ctx.attr.resource_dir:
        resource_dir_feature = [feature(
            name = "resource_dir",
            enabled = True,
            flag_sets = [flag_set(
                actions = all_compile + all_link,
                flag_groups = [flag_group(flags = [
                    "-resource-dir",
                    ctx.attr.resource_dir,
                ])],
            )],
        )]

    features = resource_dir_feature + [
        feature(
            name = "archiver_flags",
            enabled = True,
            flag_sets = [flag_set(
                actions = [ACTION_NAMES.cpp_link_static_library],
                flag_groups = [
                    flag_group(
                        flags = ["rcsD", "%{output_execpath}"],
                        expand_if_available = "output_execpath",
                    ),
                    flag_group(
                        iterate_over = "libraries_to_link",
                        flag_groups = [flag_group(
                            flags = ["%{libraries_to_link.name}"],
                            expand_if_equal = variable_with_value(
                                name = "libraries_to_link.type",
                                value = "object_file",
                            ),
                        )],
                        expand_if_available = "libraries_to_link",
                    ),
                ],
            )],
        ),
        feature(
            name = "default_compile_flags",
            enabled = True,
            flag_sets = [
                flag_set(
                    actions = all_compile,
                    flag_groups = [flag_group(flags = [
                        "--target=" + target,
                        "-U_FORTIFY_SOURCE",
                        "-fstack-protector",
                        "-fno-omit-frame-pointer",
                        "-fcolor-diagnostics",
                        "-Wall",
                        "-Wthread-safety",
                        "-Wself-assign",
                    ])],
                ),
                flag_set(
                    actions = all_compile,
                    flag_groups = [flag_group(flags = ["-g", "-fstandalone-debug"])],
                    with_features = [with_feature_set(features = ["dbg"])],
                ),
                flag_set(
                    actions = all_compile,
                    flag_groups = [flag_group(flags = [
                        "-g0",
                        "-O2",
                        "-D_FORTIFY_SOURCE=1",
                        "-DNDEBUG",
                        "-ffunction-sections",
                        "-fdata-sections",
                    ])],
                    with_features = [with_feature_set(features = ["opt"])],
                ),
            ],
        ),
        feature(
            name = "default_link_flags",
            enabled = True,
            flag_sets = [
                flag_set(
                    actions = all_link,
                    flag_groups = [flag_group(flags = [
                        "--target=" + target,
                        "-no-canonical-prefixes",
                        "-fuse-ld=lld",
                        "-Wl,--build-id=md5",
                        "-Wl,--hash-style=gnu",
                        "-Wl,-z,relro,-z,now",
                        "-lstdc++",
                        "-lm",
                    ])],
                ),
                flag_set(
                    actions = all_link,
                    flag_groups = [flag_group(flags = ["-Wl,--gc-sections"])],
                    with_features = [with_feature_set(features = ["opt"])],
                ),
            ],
        ),
        feature(name = "dbg"),
        feature(name = "opt"),
        feature(name = "fastbuild"),
        feature(name = "supports_pic", enabled = True),
        feature(name = "supports_dynamic_linker", enabled = True),
        feature(name = "coverage"),
        feature(
            name = "llvm_coverage_map_format",
            provides = ["profile"],
            flag_sets = [
                flag_set(
                    actions = cc_compile,
                    flag_groups = [flag_group(flags = [
                        "-fprofile-instr-generate",
                        "-fcoverage-mapping",
                    ])],
                ),
                flag_set(
                    actions = all_link,
                    flag_groups = [flag_group(flags = [
                        "-fprofile-instr-generate",
                    ])],
                ),
            ],
        ),
        feature(
            name = "user_compile_flags",
            enabled = True,
            flag_sets = [flag_set(
                actions = all_compile,
                flag_groups = [flag_group(
                    flags = ["%{user_compile_flags}"],
                    iterate_over = "user_compile_flags",
                    expand_if_available = "user_compile_flags",
                )],
            )],
        ),
        feature(
            name = "sysroot",
            enabled = True,
            flag_sets = [flag_set(
                actions = all_compile + all_link,
                flag_groups = [flag_group(
                    flags = ["--sysroot=%{sysroot}"],
                    expand_if_available = "sysroot",
                )],
            )],
        ),
        feature(
            name = "unfiltered_compile_flags",
            enabled = True,
            flag_sets = [flag_set(
                actions = all_compile,
                flag_groups = [flag_group(flags = [
                    "-no-canonical-prefixes",
                    "-Wno-builtin-macro-redefined",
                    '-D__DATE__="redacted"',
                    '-D__TIMESTAMP__="redacted"',
                    '-D__TIME__="redacted"',
                ])],
            )],
        ),
        feature(
            name = "user_link_flags",
            enabled = True,
            flag_sets = [flag_set(
                actions = all_link,
                flag_groups = [flag_group(
                    flags = ["%{user_link_flags}"],
                    iterate_over = "user_link_flags",
                    expand_if_available = "user_link_flags",
                )],
            )],
        ),
    ]

    return cc_common.create_cc_toolchain_config_info(
        ctx = ctx,
        features = features,
        tool_paths = tool_path_list,
        cxx_builtin_include_directories = ctx.attr.cxx_builtin_include_directories,
        toolchain_identifier = ctx.attr.toolchain_identifier,
        target_system_name = target,
        target_cpu = ctx.attr.target_cpu,
        target_libc = "glibc",
        compiler = "clang",
        abi_version = "clang",
        abi_libc_version = "glibc",
        builtin_sysroot = ctx.attr.sysroot_path,
    )

chromium_cc_toolchain_config = rule(
    implementation = _impl,
    attrs = {
        "target_system_name": attr.string(mandatory = True),
        "target_cpu": attr.string(mandatory = True),
        "toolchain_identifier": attr.string(mandatory = True),
        "sysroot_path": attr.string(default = ""),
        "resource_dir": attr.string(default = "", doc = "Exec-root-relative path to Clang's resource dir (lib/clang/<ver>)."),
        "cxx_builtin_include_directories": attr.string_list(default = []),
    },
    provides = [CcToolchainConfigInfo],
)
