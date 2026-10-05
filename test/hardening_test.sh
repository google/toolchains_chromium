#!/bin/sh
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

set -e

binary="$1"
output=$("$binary" 2>&1) && { echo "FAIL: expected nonzero exit"; exit 1; }
echo "$output" | grep -q "libc++ Hardening assertion" || { echo "FAIL: expected a libc++ hardening assertion in output:"; echo "$output"; exit 1; }
echo "PASS: libc++ hardening aborted on an out-of-bounds access"
