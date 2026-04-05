# Run integration tests
test:
    cd test && bazel test //...

# Verify hermetic coverage produces real LCOV data
coverage:
    #!/usr/bin/env bash
    set -euo pipefail
    cd test
    bazel coverage //...
    report="$(bazel info output_path)/_coverage/_coverage_report.dat"
    bazel run :check_coverage -- "$report" "$PWD/coverage_lib.cc"

# Run all checks
test-all: test coverage
