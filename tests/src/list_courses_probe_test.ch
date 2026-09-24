// Probe: list_courses scans ./courses for multiple known courses.
// Kept as a permanent regression test for the read_dir reference-capture bug.
using std::string
using std::string_view
using std::vector

@test
public func test_list_courses_scans_dir(env : &mut TestEnv) {
    var courses_dir = string("./courses")
    var courses = underlayer_repository::list_courses(&courses_dir)
    if(courses.size() < 2) { env.error("list_courses found fewer than 2 courses — read_dir scan not working") }
    var found_elf = false
    var found_hat = false
    var i : size_t = 0
    while(i < courses.size()) {
        var cptr = courses.get_ptr(i)
        var cid = cptr.id.copy()
        var elf_id = string("elf")
        var hat_id = string("hat")
        if(cid.equals(&elf_id)) { found_elf = true }
        if(cid.equals(&hat_id)) { found_hat = true }
        i = i + 1
    }
    if(!found_elf) { env.error("elf course missing from scan") }
    if(!found_hat) { env.error("hat course missing from scan") }
}
