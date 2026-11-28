// Underlayer — Docker/CI entry point.
//
// Mirrors chemical.mod; the ONLY difference is the brand-layer import: a local
// checkout uses ../../WebLibs/brandlib, while Docker resolves it from GitHub.
// The Dockerfile copies this file over chemical.mod before building. The web/
// submodule has its own chemical.cloud.mod for the same reason — keep both in
// lockstep with their local twins (import lists must match except brandlib).

application underlayer

source "app" if !test
source "tests" if test

import std
import cstd
import http
import json
import page
import web
import html_cbi
import css_cbi
import js_cbi
import universal_cbi
import components
import "github.com/wiqis/brandlib"
import fs
import net
import encoding
import uuid
// E1/E6: course-local render modules. Keep in lockstep with chemical.mod.
import "./courses/binread"
import "./courses/front"

import test if test
import test_env if test

link "m" if linux

// Internal modules (relative imports)
import "./core"
import "./database"
import "./models"
import "./repository"
import "./learning"
import "./content"
import "./web"
