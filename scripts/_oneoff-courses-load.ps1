# Rewrite load_course_from_disk (repository/src/courses.ch) as a JSON-read that
# uses the reference-based helpers.  Replaces the body between
# "public func load_course_from_disk" and the closing brace before
# "private func load_course_hardcoded".
$path = 'D:\Programming\Wiqis\Web\underlayer\repository\src\courses.ch'
$lines = [System.IO.File]::ReadAllLines($path)
$start = -1; $end = -1
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match 'public func load_course_from_disk') { $start = $i }
    if ($start -ge 0 -and $lines[$i] -match 'private func load_course_hardcoded') { $end = $i; break }
}
if ($start -lt 0 -or $end -lt 0) { throw "markers not found start=$start end=$end" }

$body = @'
    public func load_course_from_disk(courses_dir : &string, course_id : &string) : Course {
        var course = Course::make()
        var path = courses_dir.copy()
        path.append_view(string_view("/"))
        path.append_string(course_id)
        path.append_view(string_view("/manifest.json"))
        var path_view = std::str.make_view(path.to_view())
        var manifest_path = path::Path.new(path_view)
        var content_res = fs::read_to_string(&manifest_path)
        if(content_res is std::Result.Err) {
            return course
        }
        var Ok(text) = content_res else unsafe { unreachable }
        var json_res = json::parse(text.to_view())
        if(json_res is std::Result.Err) {
            return course
        }
        var Ok(root) = json_res else unsafe { unreachable }
        course.id = json_get_str(&root, "id")
        course.title = json_get_str(&root, "title")
        course.version = json_get_int(&root, "version")
        if(course.version == 0) { course.version = 1 }
        course.description = json_get_str(&root, "description")
        course.author = json_get_str(&root, "author")
        course.license = json_get_str(&root, "license")
        course.language = json_get_str(&root, "language")
        if(course.language.size() == 0) { course.language = string("en") }
        course.difficulty = json_get_str(&root, "difficulty")
        if(course.difficulty.size() == 0) { course.difficulty = string("intermediate") }
        course.importance = json_get_str(&root, "importance")
        if(course.importance.size() == 0) { course.importance = string("core") }
        course.completion_criteria = json_get_str(&root, "completion_criteria")
        if(course.completion_criteria.size() == 0) { course.completion_criteria = string("all_concepts") }
        course.min_score = json_get_int(&root, "min_score") as f64
        // 2.1.9: Parse branching
        course.branching = json_get_bool(&root, "branching")
        // 2.1.9: Parse alternative paths
        var paths_node = json_get(&root, "alternative_paths")
        if(paths_node is std::Option.Some) {
            var Some(paths_arr) = paths_node else unsafe { unreachable }
            var pi : size_t = 0
            while(pi < json_len(paths_arr)) {
                var pe = json_at(paths_arr, pi)
                var Some(pval) = pe else unsafe { unreachable }
                var bp = BranchPath::make()
                if(pval is JsonValue.Object) {
                    bp.from_concept = json_get_str(pval, "from_concept")
                    bp.to_concept = json_get_str(pval, "to_concept")
                    bp.condition = json_get_str(pval, "condition")
                    bp.description = json_get_str(pval, "description")
                }
                course.alternative_paths.push(bp)
                pi = pi + 1
            }
        }
        // 2.1.10: Parse bundles
        var bundles_node = json_get(&root, "bundles")
        if(bundles_node is std::Option.Some) {
            var Some(bundles_arr) = bundles_node else unsafe { unreachable }
            var bi : size_t = 0
            while(bi < json_len(bundles_arr)) {
                var be = json_at(bundles_arr, bi)
                var Some(bval) = be else unsafe { unreachable }
                var bundle = CourseBundle::make()
                if(bval is JsonValue.Object) {
                    bundle.id = json_get_str(bval, "id")
                    bundle.title = json_get_str(bval, "title")
                    var cids_node = json_get(bval, "course_ids")
                    if(cids_node is std::Option.Some) {
                        var Some(cids_arr) = cids_node else unsafe { unreachable }
                        var ci2 : size_t = 0
                        while(ci2 < json_len(cids_arr)) {
                            var ce = json_at(cids_arr, ci2)
                            var Some(cidv) = ce else unsafe { unreachable }
                            if(cidv is JsonValue.String) {
                                bundle.course_ids.push(json_str(cidv))
                            }
                            ci2 = ci2 + 1
                        }
                    }
                }
                course.bundles.push(bundle)
                bi = bi + 1
            }
        }
        // 2.1.13: Parse min_platform_version
        course.min_platform_version = json_get_str(&root, "min_platform_version")
        if(course.min_platform_version.size() == 0) { course.min_platform_version = string("1.0") }
        // 2.1.14: Parse assets
        var assets_node = json_get(&root, "assets")
        if(assets_node is std::Option.Some) {
            var Some(assets_arr) = assets_node else unsafe { unreachable }
            var ai : size_t = 0
            while(ai < json_len(assets_arr)) {
                var ae = json_at(assets_arr, ai)
                var Some(aval) = ae else unsafe { unreachable }
                var asset = CourseAsset::make()
                if(aval is JsonValue.Object) {
                    asset.id = json_get_str(aval, "id")
                    asset.asset_type = json_get_str(aval, "asset_type")
                    asset.path = json_get_str(aval, "path")
                    asset.description = json_get_str(aval, "description")
                    asset.concept_id = json_get_str(aval, "concept_id")
                }
                course.assets.push(asset)
                ai = ai + 1
            }
        }
        // 2.1.15: Parse review_item_decls
        var rids_node = json_get(&root, "review_item_decls")
        if(rids_node is std::Option.Some) {
            var Some(rids_arr) = rids_node else unsafe { unreachable }
            var ri : size_t = 0
            while(ri < json_len(rids_arr)) {
                var re = json_at(rids_arr, ri)
                var Some(rval) = re else unsafe { unreachable }
                var rid = ReviewItemDecl::make()
                if(rval is JsonValue.Object) {
                    rid.concept_id = json_get_str(rval, "concept_id")
                    rid.item_type = json_get_str(rval, "item_type")
                    rid.front = json_get_str(rval, "front")
                    rid.back = json_get_str(rval, "back")
                    rid.difficulty = json_get_int(rval, "difficulty") as f64
                    if(rid.difficulty == 0.0) { rid.difficulty = 0.5 }
                }
                course.review_item_decls.push(rid)
                ri = ri + 1
            }
        }
        // 2.1.16: Parse exercise_decls
        var edecl_node = json_get(&root, "exercise_decls")
        if(edecl_node is std::Option.Some) {
            var Some(edecl_arr) = edecl_node else unsafe { unreachable }
            var ei : size_t = 0
            while(ei < json_len(edecl_arr)) {
                var ee = json_at(edecl_arr, ei)
                var Some(eval_) = ee else unsafe { unreachable }
                var edecl = ExerciseDecl::make()
                if(eval_ is JsonValue.Object) {
                    edecl.concept_id = json_get_str(eval_, "concept_id")
                    edecl.exercise_type = json_get_str(eval_, "exercise_type")
                    edecl.question = json_get_str(eval_, "question")
                    edecl.answer = json_get_str(eval_, "answer")
                    var opts_node = json_get(eval_, "options")
                    if(opts_node is std::Option.Some) {
                        var Some(opts_arr) = opts_node else unsafe { unreachable }
                        var oi : size_t = 0
                        while(oi < json_len(opts_arr)) {
                            var oe = json_at(opts_arr, oi)
                            var Some(oval) = oe else unsafe { unreachable }
                            if(oval is JsonValue.String) {
                                edecl.options.push(json_str(oval))
                            }
                            oi = oi + 1
                        }
                    }
                    edecl.correct_index = json_get_int(eval_, "correct_index")
                    edecl.explanation = json_get_str(eval_, "explanation")
                    edecl.difficulty = json_get_int(eval_, "difficulty") as f64
                    if(edecl.difficulty == 0.0) { edecl.difficulty = 0.5 }
                }
                course.exercise_decls.push(edecl)
                ei = ei + 1
            }
        }
        // 2.1.17: Parse visualization_decls
        var vdecl_node = json_get(&root, "visualization_decls")
        if(vdecl_node is std::Option.Some) {
            var Some(vdecl_arr) = vdecl_node else unsafe { unreachable }
            var vi : size_t = 0
            while(vi < json_len(vdecl_arr)) {
                var ve = json_at(vdecl_arr, vi)
                var Some(vval) = ve else unsafe { unreachable }
                var vdecl = VisualizationDecl::make()
                if(vval is JsonValue.Object) {
                    vdecl.concept_id = json_get_str(vval, "concept_id")
                    vdecl.vis_type = json_get_str(vval, "vis_type")
                    vdecl.title = json_get_str(vval, "title")
                    vdecl.data_source = json_get_str(vval, "data_source")
                    vdecl.config = json_get_str(vval, "config")
                }
                course.visualization_decls.push(vdecl)
                vi = vi + 1
            }
        }
        // 2.1.18: Parse navigation
        course.navigation = json_get_str(&root, "navigation")
        if(course.navigation.size() == 0) { course.navigation = string("linear") }
        // 2.1.20: Parse certificate
        var cert_node = json_get(&root, "certificate")
        if(cert_node is std::Option.Some) {
            var Some(cert_val) = cert_node else unsafe { unreachable }
            course.certificate.template_id = json_get_str(cert_val, "template_id")
            course.certificate.badge_url = json_get_str(cert_val, "badge_url")
            course.certificate.title = json_get_str(cert_val, "title")
            course.certificate.description = json_get_str(cert_val, "description")
            course.certificate.criteria = json_get_str(cert_val, "criteria")
        }
        // 2.1.12: Parse dependencies
        var deps_node = json_get(&root, "dependencies")
        if(deps_node is std::Option.Some) {
            var Some(deps_arr) = deps_node else unsafe { unreachable }
            var di : size_t = 0
            while(di < json_len(deps_arr)) {
                var de = json_at(deps_arr, di)
                var Some(dval) = de else unsafe { unreachable }
                if(dval is JsonValue.String) {
                    course.dependencies.push(json_str(dval))
                }
                di = di + 1
            }
        }
        var modules_node = json_get(&root, "modules")
        if(modules_node is std::Option.Some) {
            var Some(modules_arr) = modules_node else unsafe { unreachable }
            var mi : size_t = 0
            while(mi < json_len(modules_arr)) {
                var me = json_at(modules_arr, mi)
                var Some(mod_val) = me else unsafe { unreachable }
                var mod = Module::make()
                mod.id = json_get_str(mod_val, "id")
                mod.title = json_get_str(mod_val, "title")
                mod.description = json_get_str(mod_val, "description")
                mod.order = mi as int + 1
                var concepts_node = json_get(mod_val, "concepts")
                if(concepts_node is std::Option.Some) {
                    var Some(concepts_arr) = concepts_node else unsafe { unreachable }
                    var ci : size_t = 0
                    while(ci < json_len(concepts_arr)) {
                        var ce = json_at(concepts_arr, ci)
                        var Some(cval) = ce else unsafe { unreachable }
                        if(cval is JsonValue.String) {
                            mod.concepts.push(json_str(cval))
                        }
                        ci = ci + 1
                    }
                }
                course.modules.push(mod)
                mi = mi + 1
            }
        }
        var cnode = json_get(&root, "concepts")
        if(cnode is std::Option.Some) {
            var Some(concepts_arr) = cnode else unsafe { unreachable }
            var ci : size_t = 0
            while(ci < json_len(concepts_arr)) {
                var ce = json_at(concepts_arr, ci)
                var Some(cval) = ce else unsafe { unreachable }
                var cref = ConceptRef::make()
                if(cval is JsonValue.Object) {
                    cref.id = json_get_str(cval, "id")
                    cref.title = json_get_str(cval, "title")
                    cref.module_id = json_get_str(cval, "module_id")
                    cref.description = json_get_str(cval, "description")
                    cref.estimated_minutes = json_get_int(cval, "estimated_minutes")
                    if(cref.estimated_minutes == 0) { cref.estimated_minutes = 10 }
                    cref.difficulty = json_get_str(cval, "difficulty")
                    if(cref.difficulty.size() == 0) { cref.difficulty = string("intermediate") }
                    cref.importance = json_get_str(cval, "importance")
                    if(cref.importance.size() == 0) { cref.importance = string("core") }
                } else if(cval is JsonValue.String) {
                    cref.id = json_str(cval)
                }
                course.concepts.push(cref)
                ci = ci + 1
            }
        }
        return course
    }

'@ -split "`r?`n"

$out = @()
if ($start -gt 0) { $out += $lines[0..($start - 1)] }
$out += $body
if ($end -lt $lines.Count) { $out += $lines[$end..($lines.Count - 1)] }
$enc = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllLines($path, $out, $enc)
Write-Output "rewrote load_course_from_disk: lines $($start+1)..$end replaced"
