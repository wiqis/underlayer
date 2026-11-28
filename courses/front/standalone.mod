// Static-page build entry for the front course. The library `chemical.mod`
// deliberately excludes build/main.ch so the root server can import the module
// without a duplicate main; this manifest is used only by scripts/build_static.sh.
application front_course_build

source "src"
source "build"

import std
import cstd
import page
import html_cbi
import css_cbi
import js_cbi
import fs
import "../../content"
import "../../core"
