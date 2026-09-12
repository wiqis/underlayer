// Underlayer — AI-native learning platform for binary formats
// Phase 1: Foundation — minimal working platform serving static courses

application underlayer

source "src"

import std
import cstd
import server
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

link "m" if linux

// Internal modules (relative imports)
import "./core"
import "./database"
import "./models"
import "./repository"
import "./web"
