// Template preview — renders the 4 concept templates to HTML files.
// Build (from repo root):
//   /d/Programming/Chemical/chemical/cmake-build-debug/TCCCompiler.exe tools/templates_preview/chemical.mod -o build/templates-preview.exe --mode debug_quick --no-cache
// Run (from repo root): ./build/templates-preview.exe
application templates_preview

source "src"

import std
import cstd
import page
import html_cbi
import css_cbi
import js_cbi
import universal_cbi
import components
import fs

import "../../content"
