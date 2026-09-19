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

"""Repository rule that fetches the libc++, libc++abi and llvm-libc sources.

The sources come from the same llvm-project revisions Chromium builds its
libc++ from (see defaults.bzl), as gitiles "subpath" archives
(`+archive/<revision>/<subpath>.tar.gz`), one per directory we need. Only
Bazel's own download/extract/read/write primitives are used: no host tool is
executed at fetch time.

Content pinning. Gitiles tarballs are generated on the fly and are not
byte-stable, so their sha256 cannot be pinned. Instead every archive is pinned
by the sha256 of a canonical *content* blob: the extracted regular files,
sorted by path, concatenated as `<relative path> NUL <content> NUL`. The blob
is handed to `repository_ctx.download("file://...", sha256 = pin)`, which is
the only hashing primitive available in Starlark. `download` consults the
repository cache before touching the URL, so the source tree is then
reconstructed *from the verified blob* (never from the extracted archive
directly): whatever `download` hands back is content whose hash equals the
pin, whether it came from the local blob or from a cache populated by an
earlier verified fetch.

To (re)compute a pin, set it to any wrong value and fetch: Bazel reports
"Checksum was <actual> but wanted <pin>".

The rule also renders libc++'s `include/__config_site` from upstream's
`__config_site.in` and installs the upstream default `__assertion_handler`,
the two files a CMake build would generate.
"""

# `__config_site.in` option values, i.e. what a CMake configure of this
# toolchain's libc++ would produce. Keys must match the `#cmakedefine` lines
# of the template exactly; the renderer fails on any unknown or missing name so
# that a revision bump that adds or removes an option is noticed.
#   None   -> `/* #undef NAME */`
#   True   -> `#define NAME` (plain) or `#define NAME 1` (`#cmakedefine01`)
#   False  -> `/* #undef NAME */` (plain) or `#define NAME 0` (`#cmakedefine01`)
#   string -> `#define NAME <string>`
_CONFIG_SITE = {
    # Unstable ABI (ABI v2) under a toolchain-private inline namespace. Objects
    # compiled by this toolchain are not ABI-compatible with any other libc++.
    "_LIBCPP_ABI_VERSION": "2",
    "_LIBCPP_ABI_NAMESPACE": "__tc",
    "_LIBCPP_ABI_FORCE_ITANIUM": False,
    "_LIBCPP_ABI_FORCE_MICROSOFT": False,
    "_LIBCPP_HAS_THREADS": True,
    "_LIBCPP_HAS_MONOTONIC_CLOCK": True,
    "_LIBCPP_HAS_MUSL_LIBC": False,
    "_LIBCPP_HAS_THREAD_API_PTHREAD": True,
    "_LIBCPP_HAS_THREAD_API_EXTERNAL": False,
    "_LIBCPP_HAS_THREAD_API_WIN32": False,
    "_LIBCPP_HAS_THREAD_API_C11": False,
    # Visibility annotations stay on for user code; the static runtime archives
    # disable them on their own compile lines (see libcxx_targets.bzl).
    "_LIBCPP_DISABLE_VISIBILITY_ANNOTATIONS": None,
    "_LIBCPP_HAS_VENDOR_AVAILABILITY_ANNOTATIONS": False,
    "_LIBCPP_NO_VCRUNTIME": None,
    "_LIBCPP_TYPEINFO_COMPARISON_IMPLEMENTATION": None,
    "_LIBCPP_HAS_FILESYSTEM": True,
    "_LIBCPP_HAS_RANDOM_DEVICE": True,
    "_LIBCPP_HAS_LOCALIZATION": True,
    "_LIBCPP_HAS_UNICODE": True,
    "_LIBCPP_HAS_WIDE_CHARACTERS": True,
    "_LIBCPP_HAS_TIME_ZONE_DATABASE": True,
    # The std::string ASan container annotations are only correct when the
    # library itself is ASan-instrumented, which no toolchain feature
    # guarantees yet. 0 is always safe (checks are merely not performed).
    "_LIBCPP_INSTRUMENTED_WITH_ASAN": False,
    "_LIBCPP_PSTL_BACKEND_SERIAL": None,
    "_LIBCPP_PSTL_BACKEND_STD_THREAD": True,
    "_LIBCPP_PSTL_BACKEND_LIBDISPATCH": None,
    # Hardened by default, failures abort with a message. A target opts down
    # with e.g. local_defines = ["_LIBCPP_HARDENING_MODE=_LIBCPP_HARDENING_MODE_FAST"].
    "_LIBCPP_HARDENING_MODE_DEFAULT": "_LIBCPP_HARDENING_MODE_EXTENSIVE",
    "_LIBCPP_ASSERTION_SEMANTIC_DEFAULT": "_LIBCPP_ASSERTION_SEMANTIC_ENFORCE",
    "_LIBCPP_LIBC_PICOLIBC": False,
    "_LIBCPP_LIBC_NEWLIB": False,
    "_LIBCPP_LIBC_LLVM_LIBC": False,
}

# Defaults that a compile line may override with -D: rendered inside
# `#ifndef` so that an explicit definition wins instead of being silently
# clobbered by this (system) header.
_CONFIG_SITE_OVERRIDABLE = [
    "_LIBCPP_INSTRUMENTED_WITH_ASAN",
    "_LIBCPP_HARDENING_MODE_DEFAULT",
    "_LIBCPP_ASSERTION_SEMANTIC_DEFAULT",
]

# Substitutions for the two free-form slots at the end of the template.
_CONFIG_SITE_SLOTS = {
    "@_LIBCPP_ABI_DEFINES@": "",
    # Drop the ABI-compatibility shims the library keeps for programs built
    # against older headers; headers and library always ship together here.
    "@_LIBCPP_EXTRA_SITE_DEFINES@": "#define _LIBCPP_AVAILABILITY_MINIMUM_HEADER_VERSION 999",
}

def _render_config_site(template):
    """Applies CMake `configure_file` semantics to `__config_site.in`."""
    seen = {}
    out = []
    for line in template.split("\n"):
        words = [word for word in line.replace("\t", " ").split(" ") if word]
        if len(words) >= 2 and words[0] in ("#cmakedefine", "#cmakedefine01"):
            name = words[1]
            if name not in _CONFIG_SITE:
                fail("__config_site.in has an option this toolchain does not configure: %s" % name)
            seen[name] = True
            value = _CONFIG_SITE[name]
            if words[0] == "#cmakedefine01":
                rendered = "#define %s %d" % (name, 1 if value else 0)
            elif value == None or value == False:
                rendered = "/* #undef %s */" % name
            else:
                rest = " ".join(words[2:])
                if "@" in rest:
                    rest = rest.replace("@%s@" % name, value)
                elif type(value) == "string":
                    rest = value
                rendered = ("#define %s %s" % (name, rest)).rstrip()
            if name in _CONFIG_SITE_OVERRIDABLE and rendered.startswith("#define"):
                rendered = "#ifndef %s\n#  %s\n#endif" % (name, rendered[1:])
            out.append(rendered)
        elif line.strip() in _CONFIG_SITE_SLOTS:
            out.append(_CONFIG_SITE_SLOTS[line.strip()])
        else:
            if "@" in line or "#cmakedefine" in line:
                fail("unexpected template syntax in __config_site.in: %s" % line)
            out.append(line)
    for name in _CONFIG_SITE:
        if name not in seen:
            fail("__config_site.in no longer has option %s; drop it from _CONFIG_SITE" % name)
    return "\n".join(out)

def _relative_files(root):
    """Sorted repo-relative paths of every regular file below `root` (a path)."""
    files = []
    pending = [(root, "")]
    for _ in range(1000000):  # Starlark has no while loop.
        if not pending:
            break
        directory, prefix = pending.pop()
        for entry in directory.readdir(watch = "no"):
            rel = prefix + entry.basename
            if entry.is_dir:
                pending.append((entry, rel + "/"))
            else:
                files.append(rel)
    return sorted(files)

def _pack(rctx, root):
    """Canonical content blob of the tree below `root`."""
    parts = []
    for rel in _relative_files(root):
        content = rctx.read(root.get_child(rel), watch = "no")
        if "\0" in rel or "\0" in content:
            fail("%s: NUL bytes are not supported by the content pinning scheme" % rel)
        parts.append(rel)
        parts.append("\0")
        parts.append(content)
        parts.append("\0")
    return "".join(parts)

def _unpack(rctx, blob, dest):
    """Writes the files of a canonical content blob below `dest`."""
    size = len(blob)
    pos = 0
    for _ in range(1000000):
        if pos >= size:
            break
        name_end = blob.find("\0", pos)
        content_end = blob.find("\0", name_end + 1)
        if name_end < 0 or content_end < 0:
            fail("corrupt content blob for %s" % dest)
        rctx.file(dest + "/" + blob[pos:name_end], blob[name_end + 1:content_end], executable = False)
        pos = content_end + 1

def _fetch_archive(rctx, dest, urls, sha256):
    """Materialises one pinned source archive at `dest`."""
    staging = "_fetch/" + dest.replace("/", "_")
    blob = staging + ".blob"
    verified = staging + ".verified"

    # Serve from the repository cache when it already holds this content: with
    # no URL to fall back to, `download` can only succeed through the cache.
    cached = rctx.download(
        url = [],
        output = verified,
        sha256 = sha256,
        allow_fail = True,
    )
    if not cached.success:
        rctx.download_and_extract(url = urls, output = staging)
        rctx.file(blob, _pack(rctx, rctx.path(staging)), executable = False)
        rctx.delete(staging)
        rctx.download(
            url = "file://" + str(rctx.path(blob)),
            output = verified,
            sha256 = sha256,
        )
        rctx.delete(blob)

    _unpack(rctx, rctx.read(verified, watch = "no"), dest)
    rctx.delete(verified)

def _libcxx_sources_impl(rctx):
    for dest in sorted(rctx.attr.urls.keys()):
        if dest not in rctx.attr.sha256:
            fail("no content pin for source archive %s" % dest)
        if dest.startswith("/") or dest.startswith("_") or ".." in dest:
            fail("invalid source archive destination %s" % dest)
        _fetch_archive(rctx, dest, rctx.attr.urls[dest], rctx.attr.sha256[dest])
    rctx.delete("_fetch")

    # The headers CMake would generate into the include directory.
    rctx.file(
        "libcxx/include/__config_site",
        _render_config_site(rctx.read("libcxx/include/__config_site.in", watch = "no")),
        executable = False,
    )
    rctx.file(
        "libcxx/include/__assertion_handler",
        rctx.read("libcxx/vendor/llvm/default_assertion_handler.in", watch = "no"),
        executable = False,
    )

    rctx.file("BUILD.bazel", """\
load("@@{module}//libcxx:libcxx_targets.bzl", "libcxx_runtime_targets")

package(default_visibility = ["//visibility:public"])

libcxx_runtime_targets()
""".format(module = rctx.attr.toolchains_chromium_repo))

libcxx_sources = repository_rule(
    implementation = _libcxx_sources_impl,
    attrs = {
        "urls": attr.string_list_dict(
            mandatory = True,
            doc = "Destination directory (e.g. `libcxx/include`) to archive URLs.",
        ),
        "sha256": attr.string_dict(
            mandatory = True,
            doc = "Destination directory to content pin (sha256 of the canonical content blob).",
        ),
        "toolchains_chromium_repo": attr.string(
            mandatory = True,
            doc = "Canonical repo name of toolchains_chromium.",
        ),
    },
    doc = "libc++, libc++abi and llvm-libc sources plus the generated libc++ configuration headers.",
)
