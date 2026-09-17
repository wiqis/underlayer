// Probe: list_courses scans ./courses for both known courses.
// Kept as a permanent regression test for the read_dir reference-capture bug.
using std::string
using std::string_view
using std::vector

@test
public func test_list_courses_scans_dir(env : &mut TestEnv) {
    var courses_dir = string("./courses")
    var courses = underlayer_repository::list_courses(&courses_dir)
    if(courses.size() == 0) { env.error("list_courses found 0 courses — read_dir scan not working") }
    var found_elf = false
    var found_demo = false
    var i : size_t = 0
    while(i < courses.size()) {
        var c = courses.get_ptr(i)
        var cptr = courses.get_ptr(i)
        var cid = cptr.id.copy()
        var elf_id = string("elf")
        var demo_id = string("demo")
        if(cid.equals(&elf_id)) { found_elf = true }
        if(cid.equals(&demo_id)) { found_demo = true }
        i = i + 1
    }
    if(!found_elf) { env.error("elf course missing from scan") }
    if(!found_demo) { env.error("demo course missing from scan") }
}
