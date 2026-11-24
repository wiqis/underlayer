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
    var found_pe = false
    var i : size_t = 0
    while(i < courses.size()) {
        var cptr = courses.at_ref(i)
        var cid = cptr.id.copy()
        var elf_id = string("elf")
        var pe_id = string("pe")
        if(cid.equals(&elf_id)) { found_elf = true }
        if(cid.equals(&pe_id)) { found_pe = true }
        i = i + 1
    }
    if(!found_elf) { env.error("elf course missing from scan") }
    if(!found_pe) { env.error("pe course missing from scan") }
}
