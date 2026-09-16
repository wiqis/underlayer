// Content Validator — validates course content before serving.
// Build (from repo root):
//   cmake-build-debug/TCCCompiler tools/content_validator/chemical.mod -o tools/content_validator/build/content_validator.exe --mode debug_quick --no-cache
// Run: ./tools/content_validator/build/content_validator.exe courses/elf

application content_validator

source "src"

import std
import cstd
import fs
import json
