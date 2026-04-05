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

"""Validate LCOV coverage report against // COVERED and // UNCOVERED source markers."""

import sys


def main():
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} LCOV_REPORT SOURCE_FILE", file=sys.stderr)
        sys.exit(2)

    report_path, source_path = sys.argv[1], sys.argv[2]
    source_name = source_path.rsplit("/", 1)[-1]

    # Parse markers from source file.
    covered_lines = set()
    uncovered_lines = set()
    with open(source_path) as f:
        for lineno, line in enumerate(f, 1):
            # Check UNCOVERED first so "// COVERED" doesn't match it.
            if "// UNCOVERED" in line:
                uncovered_lines.add(lineno)
            elif "// COVERED" in line:
                covered_lines.add(lineno)

    assert covered_lines, f"no // COVERED markers in {source_path}"
    assert uncovered_lines, f"no // UNCOVERED markers in {source_path}"

    # Parse LCOV DA: lines for the source file.
    da = {}
    in_file = False
    with open(report_path) as f:
        for line in f:
            line = line.strip()
            if line.startswith("SF:") and line.endswith(source_name):
                in_file = True
            elif line == "end_of_record":
                if in_file:
                    break
            elif in_file and line.startswith("DA:"):
                parts = line[3:].split(",")
                da[int(parts[0])] = int(parts[1])

    assert da, f"{source_name} not found in {report_path}"

    # Validate markers against LCOV data.
    errors = []
    for lineno in sorted(covered_lines):
        count = da.get(lineno)
        if count is None:
            errors.append(f"  line {lineno} (COVERED): not in LCOV report")
        elif count == 0:
            errors.append(f"  line {lineno} (COVERED): hit count is 0")

    for lineno in sorted(uncovered_lines):
        count = da.get(lineno)
        if count is None:
            errors.append(f"  line {lineno} (UNCOVERED): not in LCOV report")
        elif count > 0:
            errors.append(f"  line {lineno} (UNCOVERED): hit count is {count}")

    if errors:
        print(f"FAIL: {source_name}")
        print("\n".join(errors))
        sys.exit(1)

    print(
        f"PASS: {source_name} — "
        f"{len(covered_lines)} covered, {len(uncovered_lines)} uncovered"
    )


if __name__ == "__main__":
    main()
