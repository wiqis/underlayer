// underlayer_repository — Course loading from disk + hardcoded fallback.
using std::string
using std::string_view
using std::vector
using underlayer_models::Course
using underlayer_models::Module
using underlayer_models::ConceptRef

public namespace underlayer_repository {

    public func load_course(courses_dir : &string, course_id : &string) : Course {
        var disk_course = load_course_from_disk(courses_dir, course_id)
        if(disk_course.id.size() > 0) {
            return disk_course
        }
        return load_course_hardcoded(course_id)
    }

    private func load_course_from_disk(courses_dir : &string, course_id : &string) : Course {
        var course = Course::make()
        var path = courses_dir.copy()
        path.append_view(string_view("/"))
        path.append_string(course_id)
        path.append_view(string_view("/manifest.json"))
        var content_res = fs::read_entire_file(path.data())
        if(content_res is std::Result.Err) {
            return course
        }
        var Ok(bytes) = content_res else unreachable
        var text = string()
        var i : size_t = 0
        while(i < bytes.size()) {
            text.append(bytes.get(i) as char)
            i = i + 1
        }
        var json_res = json::parse(text.to_view())
        if(json_res is std::Result.Err) {
            return course
        }
        var Ok(root) = json_res else unreachable
        course.id = json_get_str(&raw root, "id")
        course.title = json_get_str(&raw root, "title")
        course.version = json_get_int(&raw root, "version")
        if(course.version == 0) { course.version = 1 }
        course.description = json_get_str(&raw root, "description")
        course.author = json_get_str(&raw root, "author")
        course.license = json_get_str(&raw root, "license")
        course.language = json_get_str(&raw root, "language")
        if(course.language.size() == 0) { course.language = string("en") }
        course.difficulty = json_get_str(&raw root, "difficulty")
        if(course.difficulty.size() == 0) { course.difficulty = string("intermediate") }
        course.importance = json_get_str(&raw root, "importance")
        if(course.importance.size() == 0) { course.importance = string("core") }
        course.completion_criteria = json_get_str(&raw root, "completion_criteria")
        if(course.completion_criteria.size() == 0) { course.completion_criteria = string("all_concepts") }
        course.min_score = json_get_int(&raw root, "min_score") as f64
        // 2.1.12: Parse dependencies
        var deps_val = json_get(&raw root, "dependencies")
        if(deps_val != null && deps_val is JsonValue.Array) {
            var Array(deps_arr) = *deps_val else unreachable
            var di : size_t = 0
            while(di < deps_arr.size()) {
                var dval = deps_arr.get_ptr(di)
                if(dval is JsonValue.String) {
                    var String(dep_id) = *dval else unreachable
                    course.dependencies.push(dep_id.copy())
                }
                di = di + 1
            }
        }
        var modules_val = json_get(&raw root, "modules")
        if(modules_val != null && modules_val is JsonValue.Array) {
            var Array(modules_arr) = *modules_val else unreachable
            var mi : size_t = 0
            while(mi < modules_arr.size()) {
                var mod_val = modules_arr.get_ptr(mi)
                var mod = Module::make()
                mod.id = json_get_str(mod_val, "id")
                mod.title = json_get_str(mod_val, "title")
                mod.order = mi as int + 1
                var concepts_val = json_get(mod_val, "concepts")
                if(concepts_val != null && concepts_val is JsonValue.Array) {
                    var Array(concepts_arr) = *concepts_val else unreachable
                    var ci : size_t = 0
                    while(ci < concepts_arr.size()) {
                        var cval = concepts_arr.get_ptr(ci)
                        if(cval is JsonValue.String) {
                            var String(cid) = *cval else unreachable
                            mod.concepts.push(cid.copy())
                        }
                        ci = ci + 1
                    }
                }
                course.modules.push(mod)
                mi = mi + 1
            }
        }
        var concepts_val = json_get(&raw root, "concepts")
        if(concepts_val != null && concepts_val is JsonValue.Array) {
            var Array(concepts_arr) = *concepts_val else unreachable
            var ci : size_t = 0
            while(ci < concepts_arr.size()) {
                var cval = concepts_arr.get_ptr(ci)
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
                    var String(cid) = *cval else unreachable
                    cref.id = cid.copy()
                }
                course.concepts.push(cref)
                ci = ci + 1
            }
        }
        return course
    }

    private func load_course_hardcoded(course_id : &string) : Course {
        var course = Course::make()
        var elf_check = string("elf")
        if(course_id.equals(&elf_check)) {
            course.id = course_id.copy()
            course.title = string("Executable and Linkable Format")
            course.version = 1
            var mod1 = Module::make()
            mod1.id = string("fundamentals")
            mod1.title = string("Fundamentals")
            mod1.order = 1
            mod1.concepts.push(string("bytes"))
            mod1.concepts.push(string("binary-representation"))
            mod1.concepts.push(string("file-layout"))
            course.modules.push(mod1)
            var mod2 = Module::make()
            mod2.id = string("elf-header")
            mod2.title = string("ELF Header")
            mod2.order = 2
            mod2.concepts.push(string("elf-identification"))
            mod2.concepts.push(string("elf-header-fields"))
            mod2.concepts.push(string("entry-point"))
            course.modules.push(mod2)
            var mod3 = Module::make()
            mod3.id = string("program-headers")
            mod3.title = string("Program Headers")
            mod3.order = 3
            mod3.concepts.push(string("program-header-table"))
            mod3.concepts.push(string("segment-types"))
            mod3.concepts.push(string("memory-mapping"))
            course.modules.push(mod3)
            var mod4 = Module::make()
            mod4.id = string("sections")
            mod4.title = string("Sections")
            mod4.order = 4
            mod4.concepts.push(string("section-header-table"))
            mod4.concepts.push(string("common-sections"))
            mod4.concepts.push(string("section-vs-segment"))
            course.modules.push(mod4)
            var c1 = ConceptRef::make()
            c1.id = string("bytes")
            c1.title = string("Bytes and Binary")
            c1.module_id = string("fundamentals")
            c1.description = string("Understanding bytes.")
            course.concepts.push(c1)
            var c2 = ConceptRef::make()
            c2.id = string("binary-representation")
            c2.title = string("Binary Representation")
            c2.module_id = string("fundamentals")
            c2.description = string("How bytes encode numbers.")
            course.concepts.push(c2)
            var c3 = ConceptRef::make()
            c3.id = string("file-layout")
            c3.title = string("File Layout")
            c3.module_id = string("fundamentals")
            c3.description = string("How an ELF file is organized.")
            course.concepts.push(c3)
            var c4 = ConceptRef::make()
            c4.id = string("elf-identification")
            c4.title = string("ELF Identification")
            c4.module_id = string("elf-header")
            c4.description = string("The e_ident array.")
            course.concepts.push(c4)
            var c5 = ConceptRef::make()
            c5.id = string("elf-header-fields")
            c5.title = string("ELF Header Fields")
            c5.module_id = string("elf-header")
            c5.description = string("Every field in the ELF header.")
            course.concepts.push(c5)
            var c6 = ConceptRef::make()
            c6.id = string("entry-point")
            c6.title = string("Entry Point")
            c6.module_id = string("elf-header")
            c6.description = string("Where execution begins.")
            course.concepts.push(c6)
            var c7 = ConceptRef::make()
            c7.id = string("program-header-table")
            c7.title = string("Program Header Table")
            c7.module_id = string("program-headers")
            c7.description = string("How segments are loaded.")
            course.concepts.push(c7)
            var c8 = ConceptRef::make()
            c8.id = string("segment-types")
            c8.title = string("Segment Types")
            c8.module_id = string("program-headers")
            c8.description = string("PT_LOAD, PT_DYNAMIC, PT_INTERP.")
            course.concepts.push(c8)
            var c9 = ConceptRef::make()
            c9.id = string("memory-mapping")
            c9.title = string("Memory Mapping")
            c9.module_id = string("program-headers")
            c9.description = string("File offsets to virtual addresses.")
            course.concepts.push(c9)
            var c10 = ConceptRef::make()
            c10.id = string("section-header-table")
            c10.title = string("Section Header Table")
            c10.module_id = string("sections")
            c10.description = string("The section descriptor table.")
            course.concepts.push(c10)
            var c11 = ConceptRef::make()
            c11.id = string("common-sections")
            c11.title = string("Common Sections")
            c11.module_id = string("sections")
            c11.description = string(".text, .data, .bss, .rodata.")
            course.concepts.push(c11)
            var c12 = ConceptRef::make()
            c12.id = string("section-vs-segment")
            c12.title = string("Section vs Segment")
            c12.module_id = string("sections")
            c12.description = string("Why they are different.")
            course.concepts.push(c12)
        }
        return course
    }

    public func list_courses(courses_dir : &string) : vector<Course> {
        var courses = vector<Course>()
        var known = vector<string>()
        known.push(string("elf"))
        var i : size_t = 0
        while(i < known.size()) {
            var cid_ptr = known.get_ptr(i)
            var cid_val = cid_ptr.copy()
            var course = load_course(courses_dir, &cid_val)
            if(course.id.size() > 0) {
                courses.push(course)
            }
            i = i + 1
        }
        return courses
    }

}
