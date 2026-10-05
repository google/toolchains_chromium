# toolchains_chromium

Hermetic C++ & Rust toolchain for Bazel based on Chromium infrastructure toolchain prebuilts.

The C++ standard library is libc++, built from source by the toolchain itself
at the revisions Chromium uses; see [docs/libcxx.md](docs/libcxx.md).

## License

Apache-2.0

## Disclaimer

> [!CAUTION]
> This is **not** an officially supported Google product.
