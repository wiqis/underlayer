// Underlayer test suite — a separate application that links the service modules.
//
// WHY IT IS SEPARATE.  The suite used to be `source "tests" if test` inside the
// root manifest, which meant every `--test` build also passed the flag down to
// the dependency modules — chemicallang/sqlite3 and mongodb gate their own test
// sources on it — and a full run took hours of CPU.  A test build is a different
// program from the server, so it gets its own application: build this manifest
// WITHOUT `--test`.
//
//   cmake-build-debug/TCCCompiler tests/chemical.mod -o build/tests.exe --no-cache
//   ./build/tests.exe [--test-names "…"] [--verbose]
application underlayer_tests

source "src"

import std
import cstd
import http
import json
import page
import html_cbi
import css_cbi
import js_cbi
import universal_cbi
import components
import fs
import net
import encoding
import uuid

import test
import test_env

// The service, linked as libraries: the suite drives the same handlers, the same
// repository layer and the same course content the server does.
import "../core"
import "../database"
import "../models"
import "../repository"
import "../learning"
import "../content"
import "../web"

link "m" if linux
