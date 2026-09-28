// Multiprocessor Architecture -- build entry point.
// Renders all 8 concept pages plus the landing page to output/.
//
// Concept order: the topology first, because every number in this course is a
// claim about a PAIR of cores and a pair of cores means nothing until you can
// say which pair -- and because the memory course left behind an exclusion rule
// that names SMT siblings without ever saying what one is.  Then the three
// sharing effects, separated, because conflating them is the single most common
// error in concurrent programming and they have a factor of 60 between them.
// Then the atomic instruction, which is the only one of these costs the
// hardware imposes on a single thread.  Then the ordering rules, which are the
// part that cannot be measured here and says so.  Then NUMA, which is absent on
// this machine and whose absence is itself the lesson.  Then the three
// architectures' answers.  And last the harness, because the retractions are
// part of the course.

public func main() : int {
    fs::mkdir("output")
    printf("Rendering Multiprocessor Architecture pages...\n")

    var html = underlayer_content::render_smp_landing()
    fs::write_text_file("output/index.html", html.data() as *u8, html.size())
    printf("  -> index.html\n")

    // Module 1: The Machine You Are Measuring
    html = underlayer_content::render_smp_topology()
    fs::write_text_file("output/smp-topology.html", html.data() as *u8, html.size())
    printf("  -> smp-topology.html\n")

    html = underlayer_content::render_smp_sharing()
    fs::write_text_file("output/smp-sharing.html", html.data() as *u8, html.size())
    printf("  -> smp-sharing.html\n")

    // Module 2: The Instruction That Costs
    html = underlayer_content::render_smp_atomic()
    fs::write_text_file("output/smp-atomic.html", html.data() as *u8, html.size())
    printf("  -> smp-atomic.html\n")

    html = underlayer_content::render_smp_ordering()
    fs::write_text_file("output/smp-ordering.html", html.data() as *u8, html.size())
    printf("  -> smp-ordering.html\n")

    // Module 3: Scale, and the Other Architectures
    html = underlayer_content::render_smp_numa()
    fs::write_text_file("output/smp-numa.html", html.data() as *u8, html.size())
    printf("  -> smp-numa.html\n")

    html = underlayer_content::render_smp_three()
    fs::write_text_file("output/smp-three.html", html.data() as *u8, html.size())
    printf("  -> smp-three.html\n")

    // Module 4: The Artifact
    html = underlayer_content::render_smp_harness()
    fs::write_text_file("output/smp-harness.html", html.data() as *u8, html.size())
    printf("  -> smp-harness.html\n")

    printf("Done: 8 concepts + landing page\n")
    return 0
}
