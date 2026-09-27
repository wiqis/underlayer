// Executable Images and OS Loading — course landing page
public namespace underlayer_content {

using std::string

using std::string_view

public func render_img_landing() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Executable Images and OS Loading — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson img-landing">
            <a href="/courses" class="back-link">All courses</a>
            <h1>Executable Images and OS Loading</h1>
            <div class="lesson-meta">6 concepts &middot; 4 modules &middot; 150 min &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>What this course is about</h2>
                <p>Five courses in this chain have taught you how a file is produced. <a href="/courses/obj">Object Files</a> established what a relocatable object <em>is</em>. <a href="/courses/sym">Symbol Resolution</a> covered the tables that name things. <a href="/courses/reloc">Relocations, PIC and PIE</a> measured the cost of position independence &mdash; one relocation per datum on x86-64, two on AArch64. <a href="/courses/link">Static Linking and Linker Scripts</a> turned <code>ld --verbose</code> into a file you can edit. <a href="/courses/dyn">Dynamic Linking and Shared Libraries</a> followed the loader&rsquo;s search for every undefined symbol.</p>
                <p>Every one of those facts lives in a <strong>file</strong>. None of them is about what the kernel does when the file is run. <strong>That is this course</strong>, and the thing it is really about is a data structure with no name:</p>
                <div class="formula">
  $ cd courses/img/assets/samples &amp;&amp; ./build_samples.sh 2&gt;&amp;1 | sed -n '/I1/,/I2/p'
    argc = 1   argv[0] = ./stack
    AUX 33 0x00007b98c83c7000
    AUX 51 0x0000000000000d30
    AUX 16 0x00000000178bfbff
    AUX  6 0x0000000000001000
    AUX  3 0x0000577a01179040
    AUX  4 0x0000000000000038
    AUX  5 0x000000000000000e
    AUX  7 0x00007b98c83c9000
    AUX  9 0x0000577a0117a0a0
    AUX 25 0x00007ffe34e02049
    AUX 31 0x00007ffe34e03ff0
    AUX 15 0x00007ffe34e02059 -&gt; 'x86_64'
</div>
                <p><strong>Twenty-two entries, and not one of them is reachable from C.</strong> It is the <em>auxiliary vector</em> &mdash; the third array on the initial stack, after <code>argv</code> and <code>envp</code> &mdash; and it is the only channel between the kernel and a starting program. It is where the kernel reports where your program headers landed, where your entry point is, and where the dynamic linker went. It exists because the ELF file cannot contain the answer: the file says <code>e_entry = 0x1130</code>, which is an offset, and the program needs an address, and only the kernel knows which one it chose.</p>
                <p>Across the whole collection, <code>auxv</code>, <code>AT_PHDR</code>, <code>AT_RANDOM</code>, <code>vDSO</code> and <code>mmap_min_addr</code> appear in <strong>zero</strong> of the thirty concept files written before this one. Six concepts, in four modules:</p>
                <div class="formula">
  MODULE 1  The Handoff
            the auxiliary vector: what it is, why
            no C function returns it
            reading the initial stack by hand, and
            the off-by-one that segfaults

  MODULE 2  Reading the Values
            what each entry is for, the pointer-
            versus-size trap, and the arithmetic
            that ties the kernel to the file
            the vDSO: an ELF file with no file

  MODULE 3  The Layout
            the process map, the 64 KB floor, and
            why a hint is not a request

  MODULE 4  Rebuild It
            read the raw stack, decode it with no
            libc, check every value twice
</div>
            </div>

            <div class="unit unit-example">
                <h2>Every number here was measured</h2>
                <p>Toolchain and limits, stated up front: <strong>Linux x86-64, PIE by default, clang 21.1.8, glibc and its loader 2.43, binutils 2.46.</strong> <strong>No AArch64 machine and no Mach-O kernel were available</strong>, so nothing here is claimed about a second architecture, and that limit is recorded in <code>research.md</code> rather than smoothed over.</p>
                <p>The instrument is the unusual one: <code>/proc</code> and <code>/proc/&lt;pid&gt;/mem</code>, which let a process read the kernel&rsquo;s own live view of itself. Every claim below about what the kernel does is that output, not a paraphrase of documentation.</p>
                <div class="hex-dump">
                    <pre>$ python3 stackwalk.py 2&gt;&amp;1 | grep -E 'AT_ENTRY - AT_PHDR|vdso'
  [ok  ] AT_ENTRY - AT_PHDR == e_entry - e_phoff  -- 0x10f0 == 0x10f0
  [ok  ] AT_SYSINFO_EHDR == the base of the [vdso] mapping

$ python3 crosscheck.py 2&gt;&amp;1 | tail -3
  41/41 checks passed
  ALL CLAIMS HOLD
</pre>
                </div>
                <p>The first line is the spine of the course. <strong><code>AT_ENTRY - AT_PHDR</code> equals <code>e_entry - e_phoff</code></strong> &mdash; both <code>0x10f0</code> &mdash; where the left side came from the kernel&rsquo;s stack and the right from 24 bytes of an ELF header this script parsed itself. Two independent sources, one number, and the base the kernel chose cancels out of the subtraction. That is what makes it a check rather than a coincidence.</p>
            </div>

            <div class="unit unit-example">
                <h2>The artifact</h2>
                <p>Everything is reproducible from four tracked files. The build script writes the C sources itself, so there is exactly one source of truth:</p>
                <div class="hex-dump">
                    <pre>$ cd courses/img/assets/samples
$ ./build_samples.sh     # builds every specimen from empty
$ python3 stackwalk.py   # the reader: 18 internal checks
$ python3 crosscheck.py  # re-derives every claim: 41 checks
</pre>
                </div>
                <p><code>imgdump.c</code> is 132 lines of C that hand over the raw bytes of the initial stack and then block. <code>stackwalk.py</code> is 430 lines of Python that parse those bytes with no libc, no <code>readelf</code>, and no <code>/proc/self</code> &mdash; and then check every value against a source that did not produce it.</p>
                <p>That last clause is the discipline. A check that reads the same source twice verifies nothing, so every check in the artifact compares two things obtained by different routes: <strong>the kernel&rsquo;s <code>AT_ENTRY</code> against the file&rsquo;s <code>e_entry</code>, and <code>AT_SYSINFO_EHDR</code> against a mapping read in the same process</strong> (comparing across processes is impossible &mdash; ASLR moves the vDSO, and that mistake was made here and is documented). And when the harness caught a bug in the course&rsquo;s own parser &mdash; <code>#%018lx</code> prints zero with no <code>0x</code> prefix, so the check silently lost <code>AT_SECURE</code> &mdash; that is the argument for having it.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Start Here</h2>
                <p>If you have followed the chain, start at <a href="/courses/img/lessons/img-auxv">The Auxiliary Vector</a>. If you want the shortest path to something runnable, go straight to <a href="/courses/img/lessons/img-walk">Rebuilding the Image Reader</a>, which is the artifact and the verification discipline in one place.</p>
                <p>Either way, the thing to take away is not a list of <code>AT_</code> constants. It is that <strong>a process is a data structure the kernel wrote down, and it is readable</strong> &mdash; and that reading it, then checking every field against a second source, is the whole craft this collection has been building toward since the first hex dump.</p>
            </div>
        </div>


    render_lesson_js(&mut page)
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
