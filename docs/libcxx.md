# The C++ standard library: libc++ built from source

Chromium's Clang package ships no C++ standard library, so by default this
toolchain builds **libc++ and libc++abi from source** and links them into
everything it builds. The sysroot's libstdc++ remains available as an opt-in
(`chromium.toolchain(stdlib = "libstdc++")`).

## What you get

*   The libc++, libc++abi and llvm-libc revisions Chromium builds its own
    libc++ from (`DEPS` in a Chromium checkout; pinned in
    [`defaults.bzl`](../defaults.bzl)), fetched from the
    `chromium.googlesource.com` mirror. The current Chromium Clang is always
    tested against exactly these revisions.
*   The library is compiled **by this toolchain, with your configuration**:
    the same `-c opt`/`dbg`, `--copt`s and sanitizer flags as your code
    (so e.g. `--copt=-fsanitize=memory` gives you an MSan-instrumented libc++).
    Only a handful of library-specific flags are pinned
    ([`libcxx/libcxx_targets.bzl`](../libcxx/libcxx_targets.bzl)).
*   Standard Bazel linking semantics:
    *   static linking mode (`cc_binary`, `linkstatic = True`): `libc++.a`
        and `libc++abi.a` are linked in. The resulting executable or shared
        library carries a private copy of the runtime (see *Symbol
        visibility* below).
    *   dynamic linking mode (`cc_test` default, `linkstatic = False`):
        one `libc++.so` (libc++abi included) shared by the executable and
        its `.so` dependencies.
*   Headers served with `-nostdinc++ -isystem ...`; no `-stdlib` flag is
    needed or used.

## Configuration

`libcxx/include/__config_site` is rendered from upstream's template
(`__config_site.in`) by [`libcxx/libcxx_sources.bzl`](../libcxx/libcxx_sources.bzl):

| Setting | Value | Notes |
| --- | --- | --- |
| `_LIBCPP_ABI_VERSION` | `2` | The unstable ABI, as in Chromium. |
| `_LIBCPP_ABI_NAMESPACE` | `__tc` | Symbols are `std::__tc::...`; see *ABI* below. |
| `_LIBCPP_HARDENING_MODE_DEFAULT` | `EXTENSIVE` | See *Hardening* below. |
| `_LIBCPP_ASSERTION_SEMANTIC_DEFAULT` | `ENFORCE` | A failed check prints `file:line: libc++ Hardening assertion ... failed: <reason>` and aborts. |
| `_LIBCPP_AVAILABILITY_MINIMUM_HEADER_VERSION` | `999` | Headers and library always ship together, so no compatibility shims for older headers are compiled in. |
| `_LIBCPP_INSTRUMENTED_WITH_ASAN` | `0` | The library's string ASan annotations stay off (they require an ASan-instrumented library). |
| Threads, filesystem, localization, unicode, wide chars, random device, time zone database | on | Upstream's Linux defaults; `std::chrono` time zones need `tzdata` on the running machine. |
| PSTL backend | `std_thread` | Upstream's default with threads. |

The library itself is compiled as C++26 with exceptions and RTTI, as
upstream requires; your code can use any language standard supported by
libc++ (`-std=` is not set by the toolchain, so Clang's default applies).

## ABI

This libc++ is **not ABI-compatible with anything else**: not with libstdc++,
not with another libc++ build (different revision, ABI version or namespace).
Everything that shares C++ types, exceptions or RTTI in a process must be
built by this toolchain, and in static linking mode every linked output has
its own copy of the runtime. If a program is made of several shared
libraries that exchange standard library objects or exceptions, build it in
dynamic linking mode so that all of them use the one `libc++.so`.

Code built by this toolchain can still interoperate with other toolchains
through C interfaces.

### Symbol visibility

The static archives are compiled with hidden visibility and without libc++'s
export annotations, so nothing compiled *into* `libc++.a`/`libc++abi.a`
(`std::string::__init`, `__cxa_throw`, `std::runtime_error`'s constructors
and RTTI, ...) is exported from a shared library or executable that links
them, with two intended exceptions: the replaceable `operator new`/`operator
delete`, and the hardening failure handler `std::__libcpp_verbose_abort`,
which libc++ keeps public (and weak) so that a program can override it.

Your own translation units are compiled with *your* visibility settings. A
translation unit built without `-fvisibility=hidden` exports, besides its own
symbols, the libc++ inline code and data it instantiates and that Clang does
not mark hidden: some inline member functions (constructor templates, members
that are extern templates only in libc++'s stable ABI), inline variables,
vtables and RTTI. All of these live under `std::__tc` or are the same in
every copy of this libc++, so they cannot clash with another C++ runtime and
binding to another copy of them is harmless; they merely enlarge the dynamic
symbol table. If a shared library should export only its API, build it the way
Chromium does -- `copts = ["-fvisibility=hidden", "-fvisibility-inlines-hidden"]`
(the toolchain does not impose this on user code because it changes the
meaning of the user's own inline functions across shared libraries) -- or
use a linker version script.

`test/visibility_test.cc` checks the archive side of this contract.

## Hardening

[libc++ hardening](https://libcxx.llvm.org/Hardening.html) is enabled in
`extensive` mode: violations of standard library preconditions (out-of-bounds
`vector`/`string_view` indexing, dereferencing an empty `optional`,
`std::string(nullptr)`, ...) abort with a message instead of being undefined
behaviour. The checks live in the headers, so they apply per translation
unit at the mode that unit was compiled with. Conforming programs are not
affected.

A target that needs a different mode sets it itself:

```starlark
cc_library(
    name = "hot_loop",
    local_defines = ["_LIBCPP_HARDENING_MODE=_LIBCPP_HARDENING_MODE_FAST"],
    ...
)
```

(or `_LIBCPP_HARDENING_MODE_NONE`, or `_LIBCPP_HARDENING_MODE_DEBUG`).
Mixing modes in one program is safe: libc++ tags inline functions with the
mode they were compiled in.

## Using libstdc++ instead

```starlark
chromium.toolchain(stdlib = "libstdc++")
```

uses the sysroot's libstdc++ (GCC 10, Debian bullseye) as before libc++
existed (plus `-lpthread`, which `std::thread` needs with the sysroot's
glibc); nothing is fetched or built. CI covers it: `test/MODULE.bazel`
declares a second, unregistered toolchain with it, and `//:libstdcxx_test`
builds and runs a check with that toolchain via `--extra_toolchains` (see
[`test/toolchain_test.bzl`](../test/toolchain_test.bzl)).

## Updating the sources

1.  Copy `libcxx_revision`, `libcxxabi_revision` and `llvm_libc_revision`
    from Chromium's `DEPS` into [`defaults.bzl`](../defaults.bzl).
2.  Recompute the content pins (`LIBCXX_SOURCE_SHA256`). Gitiles archives are
    not byte-stable, so each archive is pinned by the sha256 of a canonical
    blob of its *contents*; the easiest way to get a pin is to leave the old
    one in place and read the new value from Bazel's
    `Checksum was <actual> but wanted <pin>` error. The pins must be the same
    on every Bazel version the module supports.
3.  If upstream changed `__config_site.in`, the fetch fails naming the option
    that `_CONFIG_SITE` in `libcxx_sources.bzl` does not know (or no longer
    needs); decide its value there.
4.  Compare the source lists in
    [`libcxx/libcxx_targets.bzl`](../libcxx/libcxx_targets.bzl) with
    upstream's `libcxx/src/CMakeLists.txt` and `libcxxabi/src/CMakeLists.txt`.
5.  `just test-all`.

A revision bump changes the ABI (see above); all C++ code in a build is
rebuilt against it automatically.
