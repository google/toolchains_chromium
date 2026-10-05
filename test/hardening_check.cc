// Copyright 2026 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// Violates a standard library precondition (out-of-bounds vector access).
// libc++ hardening, enabled by default, must abort with a message instead
// of silently reading past the end.

#include <cstdio>
#include <vector>

int main(int argc, char**) {
    std::vector<int> v(3);
    // The index depends on argc so the access cannot be folded away.
    int value = v[argc + 5];
    std::printf("read %d past the end without aborting\n", value);
    return 0;
}
