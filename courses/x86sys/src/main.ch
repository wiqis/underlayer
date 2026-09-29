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
    fs::mkdir("output")
    printf("Rendering The x86-64 Machine: Privilege, Memory and Time pages...\n")

    var html = underlayer_content::render_x86sys_landing()
    fs::write_text_file("output/index.html", html.data() as *u8, html.size())
    printf("  -> index.html\n")

    // Module 1: the machine's privileged side, as an inventory
    html = underlayer_content::render_x86_syscall()
    fs::write_text_file("output/x86-syscall.html", html.data() as *u8, html.size())
    printf("  -> x86-syscall.html\n")

    html = underlayer_content::render_x86_exceptions()
    fs::write_text_file("output/x86-exceptions.html", html.data() as *u8, html.size())
    printf("  -> x86-exceptions.html\n")

    html = underlayer_content::render_x86_rings()
    fs::write_text_file("output/x86-rings.html", html.data() as *u8, html.size())
    printf("  -> x86-rings.html\n")

    html = underlayer_content::render_x86_cr()
    fs::write_text_file("output/x86-cr.html", html.data() as *u8, html.size())
    printf("  -> x86-cr.html\n")

    html = underlayer_content::render_x86_debug()
    fs::write_text_file("output/x86-debug.html", html.data() as *u8, html.size())
    printf("  -> x86-debug.html\n")

    // Module 2: the address space, and which bytes of it exist
    html = underlayer_content::render_x86_virtual()
    fs::write_text_file("output/x86-virtual.html", html.data() as *u8, html.size())
    printf("  -> x86-virtual.html\n")

    html = underlayer_content::render_x86_paging()
    fs::write_text_file("output/x86-paging.html", html.data() as *u8, html.size())
    printf("  -> x86-paging.html\n")

    // Module 3: time, and the limit of what a user process can count
    html = underlayer_content::render_x86_pmu()
    fs::write_text_file("output/x86-pmu.html", html.data() as *u8, html.size())
    printf("  -> x86-pmu.html\n")

    html = underlayer_content::render_x86_boundary()
    fs::write_text_file("output/x86-boundary.html", html.data() as *u8, html.size())
    printf("  -> x86-boundary.html\n")

    printf("Done: 9 concepts + landing page\n")
    return 0
}
