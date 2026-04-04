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
    lh=$(grep -c '^LH:[1-9]' "$report" || true)
    if [ "$lh" -eq 0 ]; then
        echo "FAIL: LCOV report has no non-zero line hits"
        head -40 "$report"
        exit 1
    fi
    echo "PASS: LCOV report has $lh source files with coverage data"

# Run all checks
test-all: test coverage
