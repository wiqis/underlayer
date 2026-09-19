module underlayer_db

source "src"

import std
import cstd
import http
import json
import "../core"
// Remote module import — resolves to the published sqlite3 bindings
// (namespace `sqlite`) and is cached under build/remote/. Using the URL form
// lets the project build from its own checkout instead of requiring
// `lang/compiled/underlayer` inside the Chemical repo.
import "github.com/chemicallang/sqlite3"
