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
    course_writer::ensure_output()
    println(`Rendering Multiprocessor Architecture pages...`)

    var html = underlayer_content::render_smp_landing()
    course_writer::write_page("output/index.html", &html)
    println(`  -> index.html`)

    // Module 1: The Machine You Are Measuring
    html = underlayer_content::render_smp_topology()
    course_writer::write_page("output/smp-topology.html", &html)
    println(`  -> smp-topology.html`)

    html = underlayer_content::render_smp_sharing()
    course_writer::write_page("output/smp-sharing.html", &html)
    println(`  -> smp-sharing.html`)

    // Module 2: The Instruction That Costs
    html = underlayer_content::render_smp_atomic()
    course_writer::write_page("output/smp-atomic.html", &html)
    println(`  -> smp-atomic.html`)

    html = underlayer_content::render_smp_ordering()
    course_writer::write_page("output/smp-ordering.html", &html)
    println(`  -> smp-ordering.html`)

    // Module 3: Scale, and the Other Architectures
    html = underlayer_content::render_smp_numa()
    course_writer::write_page("output/smp-numa.html", &html)
    println(`  -> smp-numa.html`)

    html = underlayer_content::render_smp_three()
    course_writer::write_page("output/smp-three.html", &html)
    println(`  -> smp-three.html`)

    // Module 4: The Artifact
    html = underlayer_content::render_smp_harness()
    course_writer::write_page("output/smp-harness.html", &html)
    println(`  -> smp-harness.html`)

    println(`Done: 8 concepts + landing page`)
    return 0
}
