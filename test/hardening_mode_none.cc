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

// A target opts out of the default hardening mode with its own
// -D_LIBCPP_HARDENING_MODE. This must compile cleanly under -Werror (no
// macro redefinition) and link against code built in the default mode
// (the :add library): libc++'s ABI tags keep the two modes ODR-safe.

#include <vector>

#include "add.h"

static_assert(_LIBCPP_HARDENING_MODE == _LIBCPP_HARDENING_MODE_NONE);

int main() {
    std::vector<int> v = {1, 2};
    return add(v[0], v[1]) == 3 ? 0 : 1;
}
