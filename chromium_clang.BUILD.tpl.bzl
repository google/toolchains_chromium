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

package(default_visibility = ["//visibility:public"])

exports_files(glob(["bin/*", "lib/**", "include/**", "share/**"], allow_empty = True))

filegroup(
    name = "clang",
    srcs = ["bin/clang", "bin/clang++", "bin/clang-cpp"],
)

filegroup(
    name = "ld",
    srcs = ["bin/ld.lld"],
)

filegroup(
    name = "include",
    srcs = glob(["include/**/c++/**", "lib/clang/*/include/**"], allow_empty = True),
)

filegroup(name = "bin", srcs = glob(["bin/**"]))

filegroup(
    name = "lib",
    srcs = glob([
        "lib/clang/%{llvm_version}/lib/**",
        "lib/**/libc++*.a",
        "lib/**/libunwind.a",
    ], allow_empty = True),
)

filegroup(name = "ar", srcs = ["bin/llvm-ar"])
filegroup(name = "objcopy", srcs = ["bin/llvm-objcopy"])
filegroup(name = "dwp", srcs = ["bin/llvm-dwp"])
filegroup(name = "strip", srcs = ["bin/llvm-strip"])
filegroup(name = "coverage_tools", srcs = ["bin/llvm-cov", "bin/llvm-profdata"])
