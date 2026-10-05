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

"""Running a binary built with a toolchain other than the registered one.

MODULE.bazel registers the default (libc++) toolchain only. `toolchain_test`
builds its binary in a configuration whose --extra_toolchains names another
toolchain, which then wins resolution for that subtree, so a single
`bazel test //...` also covers `chromium.toolchain(stdlib = "libstdc++")`.
"""

def _extra_toolchains_transition_impl(_settings, attr):
    return {"//command_line_option:extra_toolchains": attr.extra_toolchains}

_extra_toolchains_transition = transition(
    implementation = _extra_toolchains_transition_impl,
    inputs = [],
    outputs = ["//command_line_option:extra_toolchains"],
)

def _toolchain_test_impl(ctx):
    # A 1:1 Starlark transition still turns the attribute into a list.
    binary = ctx.attr.binary[0][DefaultInfo]
    executable = ctx.actions.declare_file(ctx.label.name)
    ctx.actions.symlink(
        output = executable,
        target_file = binary.files_to_run.executable,
        is_executable = True,
    )
    return [DefaultInfo(
        executable = executable,
        runfiles = ctx.runfiles(files = [binary.files_to_run.executable]).merge(
            binary.default_runfiles,
        ),
    )]

toolchain_test = rule(
    implementation = _toolchain_test_impl,
    test = True,
    attrs = {
        "binary": attr.label(
            cfg = _extra_toolchains_transition,
            executable = True,
            mandatory = True,
            doc = "Binary to build with the extra toolchains and run as the test.",
        ),
        "extra_toolchains": attr.string_list(
            mandatory = True,
            doc = "--extra_toolchains for the binary's configuration.",
        ),
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
        ),
    },
    doc = "Runs `binary` built in a configuration with the given --extra_toolchains.",
)
