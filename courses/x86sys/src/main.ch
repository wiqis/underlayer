// The x86-64 Machine: Privilege, Memory and Time -- build entry point.
// Renders all 9 concept pages plus the landing page to output/.
//
// Concept order, and the order is the argument.  The first five concepts are
// the INVENTORY of what a ring-3 process can and cannot do to the machine it
// is running on, taken one group at a time: the instruction that gets you in,
// the exceptions that come back out, the tables the privilege checks consult,
// the control registers that select a mode, and the debug registers that are
// unreachable.  The next two are memory, where the privilege boundary turns
// into an address-space boundary and the rules about WHICH BYTES are legal
// turn out to be about the access and not the address.  The last two are
// time, and they are the two that turn the inventory into a lesson: the
// performance counters this process cannot open, and the whole of what a user
// program can and cannot learn.
public func main() : int {
    course_writer::ensure_output()
    println(`Rendering The x86-64 Machine: Privilege, Memory and Time pages...`)

    var html = underlayer_content::render_x86sys_landing()
    course_writer::write_page("output/index.html", &html)
    println(`  -> index.html`)

    // Module 1: the machine's privileged side, as an inventory
    html = underlayer_content::render_x86_syscall()
    course_writer::write_page("output/x86-syscall.html", &html)
    println(`  -> x86-syscall.html`)

    html = underlayer_content::render_x86_exceptions()
    course_writer::write_page("output/x86-exceptions.html", &html)
    println(`  -> x86-exceptions.html`)

    html = underlayer_content::render_x86_rings()
    course_writer::write_page("output/x86-rings.html", &html)
    println(`  -> x86-rings.html`)

    html = underlayer_content::render_x86_cr()
    course_writer::write_page("output/x86-cr.html", &html)
    println(`  -> x86-cr.html`)

    html = underlayer_content::render_x86_debug()
    course_writer::write_page("output/x86-debug.html", &html)
    println(`  -> x86-debug.html`)

    // Module 2: the address space, and which bytes of it exist
    html = underlayer_content::render_x86_virtual()
    course_writer::write_page("output/x86-virtual.html", &html)
    println(`  -> x86-virtual.html`)

    html = underlayer_content::render_x86_paging()
    course_writer::write_page("output/x86-paging.html", &html)
    println(`  -> x86-paging.html`)

    // Module 3: time, and the limit of what a user process can count
    html = underlayer_content::render_x86_pmu()
    course_writer::write_page("output/x86-pmu.html", &html)
    println(`  -> x86-pmu.html`)

    html = underlayer_content::render_x86_boundary()
    course_writer::write_page("output/x86-boundary.html", &html)
    println(`  -> x86-boundary.html`)

    println(`Done: 9 concepts + landing page`)
    return 0
}
