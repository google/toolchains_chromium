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

"""Building the C++ runtime with the toolchain that will link it.

A cc_toolchain cannot depend on a cc_library built by itself: the cc_library
resolves the same cc_toolchain, which is a dependency cycle. The rules below
apply a configuration transition that flips `//libcxx:bootstrap` to True for
their deps. In that configuration the toolchain declares no C++ runtime (see
chromium_toolchain_targets.bzl), so the runtime sources are compiled by a
runtime-less flavour of the same toolchain -- with everything else about the
configuration (compilation mode, platform, --copt, ...) unchanged -- and the
resulting archives / shared library are handed to the regular toolchain as
`static_runtime_lib` / `dynamic_runtime_lib`.
"""

load("@rules_cc//cc:defs.bzl", "CcInfo")

BootstrapInfo = provider(
    doc = "Value of the //libcxx:bootstrap build setting.",
    fields = ["enabled"],
)

def _libcxx_bootstrap_flag_impl(ctx):
    return [BootstrapInfo(enabled = ctx.build_setting_value)]

libcxx_bootstrap_flag = rule(
    implementation = _libcxx_bootstrap_flag_impl,
    build_setting = config.bool(flag = True),
    doc = "True while building the C++ runtime itself (no runtime is linked).",
)

def _bootstrap_transition_impl(_settings, _attr):
    return {"//libcxx:bootstrap": True}

_bootstrap_transition = transition(
    implementation = _bootstrap_transition_impl,
    inputs = [],
    outputs = ["//libcxx:bootstrap"],
)

_TRANSITION_ALLOWLIST = {
    "_allowlist_function_transition": attr.label(
        default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
    ),
}

def _bootstrapped_archives_impl(ctx):
    archives = []
    for dep in ctx.attr.deps:
        for linker_input in dep[CcInfo].linking_context.linker_inputs.to_list():
            for library in linker_input.libraries:
                # Which one exists depends on the configuration; every object
                # is compiled with -fPIC, so either is usable everywhere.
                archive = library.pic_static_library or library.static_library
                if archive:
                    archives.append(archive)

    # preorder: direct elements keep the order they were added in (link order).
    return [DefaultInfo(files = depset(archives, order = "preorder"))]

bootstrapped_archives = rule(
    implementation = _bootstrapped_archives_impl,
    attrs = {
        "deps": attr.label_list(
            cfg = _bootstrap_transition,
            providers = [CcInfo],
            doc = "cc_library targets whose archives form the static runtime, in link order.",
        ),
    } | _TRANSITION_ALLOWLIST,
    doc = "Static archives of `deps`, built with the runtime-less bootstrap toolchain.",
)

def _bootstrapped_shared_library_impl(ctx):
    files = [f for f in ctx.files.dep if f.extension == "so"]
    if len(files) != 1:
        fail("%s: expected exactly one shared library from dep, got %s" % (ctx.label, [f.path for f in files]))
    return [DefaultInfo(files = depset(files))]

bootstrapped_shared_library = rule(
    implementation = _bootstrapped_shared_library_impl,
    attrs = {
        "dep": attr.label(
            cfg = _bootstrap_transition,
            mandatory = True,
            doc = "cc_binary(linkshared = True) target producing the dynamic runtime.",
        ),
    } | _TRANSITION_ALLOWLIST,
    doc = "Shared library of `dep`, built with the runtime-less bootstrap toolchain.",
)
