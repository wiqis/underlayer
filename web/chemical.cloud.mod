// underlayer_web — Docker/CI manifest.
//
// Identical to chemical.mod except the brand layer: Docker resolves
// github.com/wiqis/brandlib, a local checkout uses ../../../WebLibs/brandlib.
// The Dockerfile copies this over web/chemical.mod before building. Keep the
// import list below in lockstep with the local manifest.

module underlayer_web

source "src"

import std
import cstd
import http
import json
import fs
import compression
import path
import encoding
import crypto
import bcrypt
import osrand
import page
import html_cbi
import css_cbi
import js_cbi
import universal_cbi
import components
import "github.com/wiqis/brandlib"
import "../core"
import "../database"
import "../models"
import "../repository"
import "../content"
import "../learning"
// E1/E6: helpers.ch dispatches to these course-local render modules.
// Keep in lockstep with web/chemical.mod.
import "../courses/binread"
import "../courses/front"
