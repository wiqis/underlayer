// Content Validator — validation logic.
// Each validator returns a vector of ValidationResult structs.
using std::string
using std::string_view
using std::vector

public namespace content_validator {

    // Local JSON helpers (mirrors web/src/json_helpers.ch)
    private func json_get(obj : *JsonValue, key : *char) : *mut JsonValue {
        if(obj == null) { return null }
        if(!(obj is JsonValue.Object)) { return null }
        var Object(map) = *obj else unreachable
        var k = string::make_no_len(key)
        return map.get_ptr(&k)
    }

    private func json_str(val : *JsonValue) : string {
        if(val == null) { return string() }
        if(val is JsonValue.String) {
            var String(s) = *val else unreachable
            return s.copy()
        }
        return string()
    }

    private func json_get_str(obj : *JsonValue, key : *char) : string {
        var field = json_get(obj, key)
        return json_str(field)
    }

    private func json_int(val : *JsonValue) : i64 {
        if(val == null) { return 0 }
        if(val is JsonValue.Number) {
            var Number(s) = *val else unreachable
            var result : i64 = 0
            var negative = false
            var i : size_t = 0
            if(s.size() > 0 && s.get(0) == '-') { negative = true; i = 1 }
            while(i < s.size()) {
                var c = s.get(i)
                if(c >= '0' && c <= '9') { result = result * 10 + (c as i64 - 48) }
                i = i + 1
            }
            if(negative) { result = -result }
            return result
        }
        return 0
    }

    private func json_get_int(obj : *JsonValue, key : *char) : int {
        var field = json_get(obj, key)
        return json_int(field) as int
    }

    public struct ValidationResult {
        var check_name : string
        var passed : bool
        var message : string
        var file_path : string
    }

    // Helper: create a passed result
    private func pass(check : &string, msg : &string) : ValidationResult {
        var r = ValidationResult::make()
        r.check_name = check.copy()
        r.passed = true
        r.message = msg.copy()
        return r
    }

    // Helper: create a failed result
    private func fail(check : &string, msg : &string, fp : &string) : ValidationResult {
        var r = ValidationResult::make()
        r.check_name = check.copy()
        r.passed = false
        r.message = msg.copy()
        r.file_path = fp.copy()
        return r
    }

    // Helper: build path = base + "/" + child
    private func join_path(base : &string, child : &string) : string {
        var p = base.copy()
        p.append_view(string_view("/"))
        p.append_string(child)
        return p
    }

    // 2.5.14: Validate manifest.json exists and is valid
    public func validate_manifest(course_dir : *string) : vector<ValidationResult> {
        var results = vector<ValidationResult>()
        var check = std::string("manifest_exists")
        var manifest_path = join_path(course_dir, &std::string("manifest.json"))

        // Check file exists
        if(!fs::exists(manifest_path.data())) {
            results.push(fail(&check, &std::string("manifest.json not found"), &manifest_path))
            return results
        }

        // Read file
        var content_res = fs::read_entire_file(manifest_path.data())
        if(content_res is std::Result.Err) {
            var Err(e) = content_res else unreachable
            results.push(fail(&check, &e.message(), &manifest_path))
            return results
        }
        var Ok(bytes) = content_res else unreachable

        // Convert bytes to string
        var text = string()
        var bi : size_t = 0
        while(bi < bytes.size()) {
            text.append(bytes.get(bi) as char)
            bi = bi + 1
        }

        // Parse JSON
        var json_res = json::parse(text.to_view())
        if(json_res is std::Result.Err) {
            results.push(fail(&check, &std::string("manifest.json is not valid JSON"), &manifest_path))
            return results
        }
        var Ok(root) = json_res else unreachable
        results.push(pass(&check, &std::string("manifest.json exists and is valid JSON")))

        // Check required fields
        var fields_check = std::string("manifest_required_fields")
        var id_val = json_get_str(&raw root, "id")
        if(id_val.size() == 0) {
            results.push(fail(&fields_check, &std::string("missing required field: id"), &manifest_path))
        } @else {
            results.push(pass(&fields_check, &std::string("required fields present")))
        }

        var title_val = json_get_str(&raw root, "title")
        if(title_val.size() == 0) {
            var r = ValidationResult::make()
            r.check_name = std::string("manifest_required_fields")
            r.passed = false
            r.message = std::string("missing required field: title")
            r.file_path = manifest_path.copy()
            results.push(r)
        }

        var version_val = json_get_int(&raw root, "version")
        if(version_val == 0) {
            var r = ValidationResult::make()
            r.check_name = std::string("manifest_required_fields")
            r.passed = false
            r.message = std::string("missing or zero version")
            r.file_path = manifest_path.copy()
            results.push(r)
        }

        // Check modules exist and have concepts
        var modules_check = std::string("manifest_modules")
        var modules_val = json_get(&raw root, "modules")
        if(modules_val == null || !(modules_val is JsonValue.Array)) {
            results.push(fail(&modules_check, &std::string("modules field missing or not an array"), &manifest_path))
            return results
        }
        var Array(modules_arr) = *modules_val else unreachable
        if(modules_arr.size() == 0) {
            results.push(fail(&modules_check, &std::string("modules array is empty"), &manifest_path))
            return results
        }

        var mi : size_t = 0
        while(mi < modules_arr.size()) {
            var mval = modules_arr.get_ptr(mi)
            if(mval is JsonValue.Object) {
                var mod_id = json_get_str(mval, "id")
                if(mod_id.size() == 0) {
                    var r = ValidationResult::make()
                    r.check_name = modules_check.copy()
                    r.passed = false
                    r.message = std::string("module at index missing id field")
                    r.file_path = manifest_path.copy()
                    results.push(r)
                }
                var concepts_val = json_get(mval, "concepts")
                if(concepts_val == null || !(concepts_val is JsonValue.Array)) {
                    var r = ValidationResult::make()
                    r.check_name = modules_check.copy()
                    r.passed = false
                    r.message = std::string("module '").append_string(&mod_id).append_view("' missing concepts array")
                    r.file_path = manifest_path.copy()
                    results.push(r)
                } @else {
                    var Array(concepts_arr) = *concepts_val else unreachable
                    if(concepts_arr.size() == 0) {
                        var r = ValidationResult::make()
                        r.check_name = modules_check.copy()
                        r.passed = false
                        r.message = std::string("module '").append_string(&mod_id).append_view("' has empty concepts array")
                        r.file_path = manifest_path.copy()
                        results.push(r)
                    }
                }
            }
            mi = mi + 1
        }

        // If we got here with no module errors, pass
        var has_module_errors = false
        var ci : size_t = 0
        while(ci < results.size()) {
            var item = results.get_ptr(ci)
            if(!item.passed && item.check_name.equals(&modules_check)) {
                has_module_errors = true
            }
            ci = ci + 1
        }
        if(!has_module_errors) {
            results.push(pass(&modules_check, &std::string("all modules have ids and non-empty concepts")))
        }

        return results
    }

    // 2.5.1: Validate concept files exist and have corresponding output
    public func validate_concept_files(course_dir : *string) : vector<ValidationResult> {
        var results = vector<ValidationResult>()
        var check = std::string("concept_files")

        var src_dir = join_path(course_dir, &std::string("src"))
        var output_dir = join_path(course_dir, &std::string("output"))

        // Check src/ directory exists
        if(!fs::exists(src_dir.data())) {
            results.push(fail(&check, &std::string("src/ directory not found"), &src_dir))
            return results
        }

        // Check output/ directory exists
        if(!fs::exists(output_dir.data())) {
            results.push(fail(&check, &std::string("output/ directory not found"), &output_dir))
            return results
        }

        // List .ch files in src/ using callback pattern
        var ch_files = vector<string>()
        var list_res = fs::read_dir(src_dir.data(), (|&ch_files|(name : *char, name_len : size_t, is_dir : bool) => {
            if(is_dir) { return true }
            // Check if name ends with .ch
            if(name_len > 3) {
                var last3 = string()
                var ci : size_t = 0
                while(ci < 3) {
                    last3.append(name[name_len - 3 + ci] as char)
                    ci = ci + 1
                }
                if(last3.equals(&std::string(".ch"))) {
                    var fname = string()
                    var fi : size_t = 0
                    while(fi < name_len) {
                        fname.append(name[fi] as char)
                        fi = fi + 1
                    }
                    ch_files.push(fname)
                }
            }
            return true
        }))

        if(list_res is std::Result.Err) {
            var Err(e) = list_res else unreachable
            results.push(fail(&check, &e.message(), &src_dir))
            return results
        }

        if(ch_files.size() == 0) {
            results.push(fail(&check, &std::string("no .ch files found in src/"), &src_dir))
            return results
        }

        // Check each .ch file has corresponding output .html
        var fi : size_t = 0
        while(fi < ch_files.size()) {
            var fname = ch_files.get_ptr(fi)
            var fpath = join_path(&src_dir, fname)

            // Check file exists and non-empty
            var meta_res = fs::metadata(fpath.data())
            if(meta_res is std::Result.Err) {
                var Err(e) = meta_res else unreachable
                results.push(fail(&check, &e.message(), &fpath))
            } @else {
                var Ok(m) = meta_res else unreachable
                if(m.len == 0) {
                    results.push(fail(&check, &std::string("file is empty"), &fpath))
                }
            }

            // Check output file exists (strip .ch, add .html)
            var html_name = string()
            var ci : size_t = 0
            while(ci < fname.size() - 3) {
                html_name.append(fname.get(ci) as char)
                ci = ci + 1
            }
            html_name.append_view(std::string(".html"))
            var html_path = join_path(&output_dir, &html_name)
            if(!fs::exists(html_path.data())) {
                var r = ValidationResult::make()
                r.check_name = std::string("concept_output_exists")
                r.passed = false
                r.message = std::string("output file missing for concept")
                r.file_path = html_path.copy()
                results.push(r)
            }

            fi = fi + 1
        }

        // If we got here, at least the files exist
        var r = ValidationResult::make()
        r.check_name = check.copy()
        r.passed = true
        r.message = std::string("found ").append_integer(ch_files.size() as i64).append_view(std::string(" concept files"))
        results.push(r)

        return results
    }

    // 2.5.6: Validate assets exist
    public func validate_assets(course_dir : *string) : vector<ValidationResult> {
        var results = vector<ValidationResult>()
        var check = std::string("asset_files")

        var manifest_path = join_path(course_dir, &std::string("manifest.json"))
        if(!fs::exists(manifest_path.data())) {
            return results
        }

        var content_res = fs::read_entire_file(manifest_path.data())
        if(content_res is std::Result.Err) { return results }
        var Ok(bytes) = content_res else unreachable

        var text = string()
        var bi : size_t = 0
        while(bi < bytes.size()) {
            text.append(bytes.get(bi) as char)
            bi = bi + 1
        }

        var json_res = json::parse(text.to_view())
        if(json_res is std::Result.Err) { return results }
        var Ok(root) = json_res else unreachable

        var assets_val = json_get(&raw root, "assets")
        if(assets_val == null || !(assets_val is JsonValue.Array)) {
            results.push(pass(&check, &std::string("no assets declared in manifest")))
            return results
        }

        var Array(assets_arr) = *assets_val else unreachable
        if(assets_arr.size() == 0) {
            results.push(pass(&check, &std::string("no assets declared in manifest")))
            return results
        }

        var assets_dir = join_path(course_dir, &std::string("assets"))
        var ai : size_t = 0
        while(ai < assets_arr.size()) {
            var aval = assets_arr.get_ptr(ai)
            if(aval is JsonValue.Object) {
                var asset_path = json_get_str(aval, "path")
                var asset_id = json_get_str(aval, "id")
                if(asset_path.size() > 0) {
                    var full_path = join_path(&assets_dir, &asset_path)
                    if(!fs::exists(full_path.data())) {
                        var r = ValidationResult::make()
                        r.check_name = std::string("asset_exists")
                        r.passed = false
                        r.message = std::string("asset '").append_string(&asset_id).append_view(std::string("' not found"))
                        r.file_path = full_path.copy()
                        results.push(r)
                    } @else {
                        // Check file size is reasonable (> 0 bytes)
                        var meta_res = fs::metadata(full_path.data())
                        if(meta_res is std::Result.Err) {
                            var Err(e) = meta_res else unreachable
                            var r = ValidationResult::make()
                            r.check_name = std::string("asset_readable")
                            r.passed = false
                            r.message = e.message()
                            r.file_path = full_path.copy()
                            results.push(r)
                        } @else {
                            var Ok(m) = meta_res else unreachable
                            if(m.len == 0) {
                                var r = ValidationResult::make()
                                r.check_name = std::string("asset_nonempty")
                                r.passed = false
                                r.message = std::string("asset '").append_string(&asset_id).append_view(std::string("' is empty"))
                                r.file_path = full_path.copy()
                                results.push(r)
                            }
                        }
                    }
                }
            }
            ai = ai + 1
        }

        var has_errors = false
        var ei : size_t = 0
        while(ei < results.size()) {
            var item = results.get_ptr(ei)
            if(!item.passed) { has_errors = true }
            ei = ei + 1
        }
        if(!has_errors) {
            var r = ValidationResult::make()
            r.check_name = check.copy()
            r.passed = true
            r.message = std::string("all ").append_integer(assets_arr.size() as i64).append_view(std::string(" assets valid"))
            results.push(r)
        }

        return results
    }

    // 2.5.7: Validate internal links in HTML output files
    public func validate_links(course_dir : *string) : vector<ValidationResult> {
        var results = vector<ValidationResult>()
        var check = std::string("internal_links")

        var output_dir = join_path(course_dir, &std::string("output"))
        if(!fs::exists(output_dir.data())) {
            results.push(fail(&check, &std::string("output/ directory not found"), &output_dir))
            return results
        }

        // List .html files in output/
        var html_files = vector<string>()
        var list_res = fs::read_dir(output_dir.data(), (|&html_files|(name : *char, name_len : size_t, is_dir : bool) => {
            if(is_dir) { return true }
            if(name_len > 5) {
                var last5 = string()
                var ci : size_t = 0
                while(ci < 5) {
                    last5.append(name[name_len - 5 + ci] as char)
                    ci = ci + 1
                }
                if(last5.equals(&std::string(".html"))) {
                    var fname = string()
                    var fi : size_t = 0
                    while(fi < name_len) {
                        fname.append(name[fi] as char)
                        fi = fi + 1
                    }
                    html_files.push(fname)
                }
            }
            return true
        }))

        if(list_res is std::Result.Err) {
            var Err(e) = list_res else unreachable
            results.push(fail(&check, &e.message(), &output_dir))
            return results
        }

        // For each HTML file, check internal links
        var fi : size_t = 0
        while(fi < html_files.size()) {
            var fname = html_files.get_ptr(fi)
            var fpath = join_path(&output_dir, fname)

            var content_res = fs::read_entire_file(fpath.data())
            if(content_res is std::Result.Err) {
                fi = fi + 1
                continue
            }
            var Ok(bytes) = content_res else unreachable

            var text = string()
            var bi : size_t = 0
            while(bi < bytes.size()) {
                text.append(bytes.get(bi) as char)
                bi = bi + 1
            }

            // Simple scan for href="..." and src="..." — extract internal links
            var i : size_t = 0
            while(i < text.size() - 5) {
                // Look for href=" or src="
                var is_href = false
                var is_src = false
                if(text.get(i) == 'h' && text.get(i + 1) == 'r' && text.get(i + 2) == 'e' && text.get(i + 3) == 'f' && text.get(i + 4) == '=' && text.get(i + 5) == '"') {
                    is_href = true
                }
                if(text.get(i) == 's' && text.get(i + 1) == 'r' && text.get(i + 2) == 'c' && text.get(i + 3) == '=' && text.get(i + 4) == '"') {
                    is_src = true
                }

                if(is_href || is_src) {
                    // Skip past ="
                    var start = i + 6
                    // Find closing "
                    var j = start
                    while(j < text.size() && text.get(j) != '"') {
                        j = j + 1
                    }
                    var link = string()
                    var li : size_t = start
                    while(li < j) {
                        link.append(text.get(li) as char)
                        li = li + 1
                    }

                    // Skip external links
                    var is_external = false
                    if(link.size() > 7) {
                        var prefix = string()
                        var pi : size_t = 0
                        while(pi < 7) {
                            prefix.append(link.get(pi) as char)
                            pi = pi + 1
                        }
                        if(prefix.equals(&std::string("http://")) || prefix.equals(&std::string("https:/"))) {
                            is_external = true
                        }
                    }
                    if(link.size() > 1 && link.get(0) == '/') {
                        is_external = true
                    }

                    if(!is_external && link.size() > 0) {
                        // Check if file exists relative to output dir
                        var target = join_path(&output_dir, &link)
                        if(!fs::exists(target.data())) {
                            var r = ValidationResult::make()
                            r.check_name = std::string("link_resolves")
                            r.passed = false
                            r.message = std::string("broken link '").append_string(&link).append_view(std::string("' in ").append_string(fname))
                            r.file_path = fpath.copy()
                            results.push(r)
                        }
                    }

                    i = j + 1
                } @else {
                    i = i + 1
                }
            }

            fi = fi + 1
        }

        var has_errors = false
        var ei : size_t = 0
        while(ei < results.size()) {
            var item = results.get_ptr(ei)
            if(!item.passed) { has_errors = true }
            ei = ei + 1
        }
        if(!has_errors) {
            var r = ValidationResult::make()
            r.check_name = check.copy()
            r.passed = true
            r.message = std::string("all internal links in ").append_integer(html_files.size() as i64).append_view(std::string(" HTML files resolve"))
            results.push(r)
        }

        return results
    }

    // 2.5.12: Validate course completeness
    public func validate_completeness(course_dir : *string) : vector<ValidationResult> {
        var results = vector<ValidationResult>()
        var check = std::string("course_completeness")

        var manifest_path = join_path(course_dir, &std::string("manifest.json"))
        if(!fs::exists(manifest_path.data())) {
            results.push(fail(&check, &std::string("manifest.json not found"), &manifest_path))
            return results
        }

        var content_res = fs::read_entire_file(manifest_path.data())
        if(content_res is std::Result.Err) { return results }
        var Ok(bytes) = content_res else unreachable

        var text = string()
        var bi : size_t = 0
        while(bi < bytes.size()) {
            text.append(bytes.get(bi) as char)
            bi = bi + 1
        }

        var json_res = json::parse(text.to_view())
        if(json_res is std::Result.Err) { return results }
        var Ok(root) = json_res else unreachable

        var output_dir = join_path(course_dir, &std::string("output"))

        // Check all concepts have output files
        var concepts_val = json_get(&raw root, "concepts")
        if(concepts_val != null && concepts_val is JsonValue.Array) {
            var Array(concepts_arr) = *concepts_val else unreachable
            var ci : size_t = 0
            while(ci < concepts_arr.size()) {
                var cval = concepts_arr.get_ptr(ci)
                if(cval is JsonValue.Object) {
                    var concept_id = json_get_str(cval, "id")
                    if(concept_id.size() > 0) {
                        var html_name = concept_id.copy()
                        html_name.append_view(std::string(".html"))
                        var html_path = join_path(&output_dir, &html_name)
                        if(!fs::exists(html_path.data())) {
                            var r = ValidationResult::make()
                            r.check_name = std::string("concept_has_output")
                            r.passed = false
                            r.message = std::string("concept '").append_string(&concept_id).append_view(std::string("' has no output file"))
                            r.file_path = html_path.copy()
                            results.push(r)
                        }
                    }
                }
                ci = ci + 1
            }
        }

        // Check modules reference valid concepts
        var modules_val = json_get(&raw root, "modules")
        if(modules_val != null && modules_val is JsonValue.Array) {
            var Array(modules_arr) = *modules_val else unreachable
            var mi : size_t = 0
            while(mi < modules_arr.size()) {
                var mval = modules_arr.get_ptr(mi)
                if(mval is JsonValue.Object) {
                    var mod_id = json_get_str(mval, "id")
                    var concepts_val2 = json_get(mval, "concepts")
                    if(concepts_val2 == null || !(concepts_val2 is JsonValue.Array)) {
                        var r = ValidationResult::make()
                        r.check_name = std::string("module_concepts_valid")
                        r.passed = false
                        r.message = std::string("module '").append_string(&mod_id).append_view(std::string("' missing concepts"))
                        r.file_path = manifest_path.copy()
                        results.push(r)
                    } @else {
                        var Array(concepts_arr2) = *concepts_val2 else unreachable
                        if(concepts_arr2.size() == 0) {
                            var r = ValidationResult::make()
                            r.check_name = std::string("module_concepts_valid")
                            r.passed = false
                            r.message = std::string("module '").append_string(&mod_id).append_view(std::string("' has no concepts"))
                            r.file_path = manifest_path.copy()
                            results.push(r)
                        }
                    }
                }
                mi = mi + 1
            }
        }

        var has_errors = false
        var ei : size_t = 0
        while(ei < results.size()) {
            var item = results.get_ptr(ei)
            if(!item.passed) { has_errors = true }
            ei = ei + 1
        }
        if(!has_errors) {
            var r = ValidationResult::make()
            r.check_name = check.copy()
            r.passed = true
            r.message = std::string("course is complete")
            results.push(r)
        }

        return results
    }

    // Run all validations
    public func validate_course(course_dir : *string) : vector<ValidationResult> {
        var results = vector<ValidationResult>()

        // 1. Manifest validation
        var manifest_results = validate_manifest(course_dir)
        var mi : size_t = 0
        while(mi < manifest_results.size()) {
            results.push(manifest_results.get(mi))
            mi = mi + 1
        }

        // 2. Concept files validation
        var concept_results = validate_concept_files(course_dir)
        var ci : size_t = 0
        while(ci < concept_results.size()) {
            results.push(concept_results.get(ci))
            ci = ci + 1
        }

        // 3. Asset validation
        var asset_results = validate_assets(course_dir)
        var ai : size_t = 0
        while(ai < asset_results.size()) {
            results.push(asset_results.get(ai))
            ai = ai + 1
        }

        // 4. Link validation
        var link_results = validate_links(course_dir)
        var li : size_t = 0
        while(li < link_results.size()) {
            results.push(link_results.get(li))
            li = li + 1
        }

        // 5. Completeness validation
        var complete_results = validate_completeness(course_dir)
        var compi : size_t = 0
        while(compi < complete_results.size()) {
            results.push(complete_results.get(compi))
            compi = compi + 1
        }

        return results
    }

}
