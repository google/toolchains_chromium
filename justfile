# Run integration tests
test:
    cd test && bazel test //...

# Verify hermetic coverage produces real LCOV data
coverage:
    #!/usr/bin/env bash
    set -euo pipefail
    cd test
    output=$(bazel coverage //... 2>&1)
    echo "$output"
    report=$(echo "$output" | grep -oP 'LCOV coverage report is located at \K\S+')
    if [ -z "$report" ]; then
        echo "FAIL: no LCOV report path in output"
        exit 1
    fi
    bazel run :check_coverage -- "$report" "$PWD/coverage_lib.cc"

# Run all checks
test-all: test coverage
