// Compiler Front End — the first link in the parsing -> executable chain.
//
// This module is deliberately self-contained: the lesson renderers live in
// courses/front/src, not content/src, because this work package owns only the
// new course directory.  It reuses the shared lesson assets (nav, 8-unit CSS,
// journey runtime) from ../../content, exactly as the other courses do.
//
// CBI dependencies are declared explicitly.  Without html_cbi / css_cbi /
// js_cbi the build fails with "couldn't find macro parser for '#html'".
module front_course

source "src"

import std
import cstd
import page
import html_cbi
import css_cbi
import js_cbi
import fs

import "../../content"
import "../../core"
