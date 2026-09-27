// Executable Images and OS Loading — Module 4: Rebuild It
// Concept: read the raw stack, decode it with no libc, check every value.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_img_walk() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Rebuilding the Image Reader — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson img-lesson">
            <a href="/courses/img" class="back-link">Back to course</a>
            <h1>Rebuilding the Image Reader</h1>
            <div class="lesson-meta">27 min &middot; Module 4: Rebuild It &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Five concepts, one artifact. The chain this collection has been building runs from a compiler&rsquo;s output to something running, and every step so far has ended at a boundary: the object file stops at the archive, the linker stops at the file, the loader stops at the process. <strong>This is the step where the boundary disappears, because the thing being parsed is not a file at all &mdash; it is a running process, and the kernel is the only thing that wrote it down.</strong></p>
                <p>So the artifact is a reader, and the discipline around it is the thing worth building. A parser that prints values is a demo. <strong>A parser that cross-checks every value against an independent source is a tool</strong>, and the difference is the entire difference between &ldquo;I think this is right&rdquo; and &ldquo;this is right, and here is why you should believe it.&rdquo;</p>
                <p>Two programs, both under 500 lines, and together they are the whole course:</p>
                <div class="hex-dump">
                    <pre>$ cd courses/img/assets/samples
$ wc -l imgdump.c stackwalk.py build_samples.sh crosscheck.py
  132 imgdump.c
  430 stackwalk.py
  330 build_samples.sh
  240 crosscheck.py
$ python3 stackwalk.py 2&gt;&amp;1 | tail -3
  18/18 checks passed
  ALL CHECKS PASS
</pre>
                </div>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>The division of labour, and it is the shape of every parser worth writing:</p>
                <div class="formula">
  imgdump.c        132 lines, in C
      the only thing that CAN read the raw
      initial stack, because it runs BEFORE
      anything else in the process and can ask
      the kernel where its own stack is.
      it does not parse. it hands over bytes
      and holds still.

  stackwalk.py     430 lines, in Python
      all the parsing. no libc, no readelf,
      no /proc/self -- just the bytes and a
      struct.unpack_from.
      and then the checking.

  build_samples.sh  the specimens, written out
      by the script itself, so there is exactly
      one source of truth.

  crosscheck.py     re-derives every claim in the
      course from a fresh run, so a claim that
      rots is a FAILING EXIT CODE, not a lie
      in a markdown file.
                </div>
                <p>The split is not arbitrary and it is the reason the thing works. <strong>A program cannot fully parse its own initial stack</strong> &mdash; not because it is hard, but because by the time your code runs, libc has consumed part of the frame. So there has to be a handoff: something inside the process that captures the bytes, and something outside that does the thinking. The boundary between those two things <em>is</em> the architecture of the tool, and it is forced by the subject matter rather than chosen for elegance.</p>
                <p>And the <code>stdin</code> block is what makes the checking sound. Without it, <code>imgdump</code> would print its bytes and exit, and the parent would read <code>/proc/&lt;pid&gt;/maps</code> of a pid that might already be gone &mdash; or worse, might have been <em>recycled</em>, so the parent reads a different process&rsquo;s map and compares it to the wrong stack. With the block, the process is provably alive and provably idle for exactly as long as the checks take.</p>
                <div class="formula">
  parent                              child
  ------                              -----
  spawn imgdump -------------------> execve
  read STACK header + bytes <------ print, fflush
  read /proc/PID/maps    <--------  BLOCKED on
  read /proc/PID/cmdline <--------  stdin, having
  parse the bytes                   executed nothing
  CHECK one against the other
  write "go\n" ------------------>  fgets returns
  waitpid ---------------------->   exit 0

  three observations, one instant.
  that is what makes the comparison mean
  something.
                </div>
            </div>

            <div class="unit unit-reality">
                <h2>Eighteen Checks, and Why Each One Earns Its Place</h2>
                <p>A check that re-reads the same source as the code under test verifies nothing. Every check below compares two things obtained by <strong>different routes</strong>, and the pairs are chosen so that a bug in one cannot hide a bug in the other.</p>
                <div class="formula">
  KERNEL  vs  FILE
  AT_PHNUM        ==  e_phnum       14  == 14
  AT_PHENT        ==  e_phentsize   56  == 56
  AT_ENTRY-AT_PHDR ==  e_entry-e_phoff
  AT_PHDR         ->  maps -> file offset == e_phoff
  AT_ENTRY        ->  maps -> file offset == e_entry

  KERNEL  vs  KERNEL (same instant)
  AT_SYSINFO_EHDR ==  base of [vdso]
  AT_EXECFN        ==  /proc/PID/cmdline[0]
  AT_RANDOM        inside the bytes we hold

  KERNEL  vs  RUNTIME
  AT_PAGESZ        ==  sysconf(_SC_PAGESIZE)
  AT_UID           ==  getuid()

  KERNEL  vs  THE KERNEL'S OWN FILE
  the child read its own startstack from
  /proc/self/stat; the parent read the same
  field from /proc/PID/stat. equal.
                </div>
                <p>The two &ldquo;kernel vs kernel&rdquo; checks are the ones that took the most work and they are the best. <strong>Comparing <code>AT_SYSINFO_EHDR</code> against a vDSO mapping read in a <em>different process</em> is impossible, because ASLR puts the vDSO somewhere different in each</strong> &mdash; that was a real mistake here, documented in <code>research.md</code>. And the <code>startstack</code> check is the cheapest and strongest of all: the child computed an address from its own <code>/proc/self/stat</code>, the parent computed the same field from <code>/proc/&lt;pid&gt;/stat</code>, and they agree. <strong>Two different readers, one number, zero shared state.</strong></p>
                <p>Three checks are deliberately weak, and it is worth being explicit about which and why. <code>AT_SECURE == 0</code>, <code>AT_UID == getuid()</code> and <code>AT_MINSIGSTKSZ</code> is plausible all pass on every normal run, and they are there as <em>regression</em> checks rather than as proofs &mdash; they would catch a parser that had started reading the wrong array, which is a real failure mode, and they cost three lines. <strong>A check you understand is worth more than a check that is merely impressive, and three honest weak checks beat one that looks strong and proves nothing.</strong></p>
            </div>

            <div class="unit unit-example">
                <h2>The Part Worth Copying</h2>
                <p>Not the auxv walk &mdash; that is in the previous concepts. This is the verification pattern, and it generalises to every parser in this collection.</p>
                <div class="hex-dump">
                    <pre>$ python3 stackwalk.py 2&gt;&amp;1 | sed -n '/KERNEL DESC/,$p'
  [ok  ] AT_PHENT == e_phentsize in the file  -- auxv 56, file 56
  [ok  ] AT_PHNUM == e_phnum in the file  -- auxv 14, file 14
  [ok  ] AT_ENTRY - AT_PHDR == e_entry - e_phoff  -- 0x10f0 == 0x10f0
  [ok  ] AT_ENTRY lands in an r-x region  -- 0x5a9b10f0f130 in .../imgdump
  [ok  ] AT_ENTRY maps to the file offset of e_entry  -- 0x1130, 0x1130
  [ok  ] AT_PHDR lands in a region of our own file
  [ok  ] AT_PHDR maps back to e_phoff  -- 0x40 vs 0x40
  [ok  ] AT_BASE lands in the dynamic linker, not in us
  [ok  ] ld.so is ET_DYN, so it must be given a base  -- e_type 3
  [ok  ] AT_PAGESZ == the system page size  -- auxv 4096, sysconf 4096
  [ok  ] AT_RANDOM points into the initial stack we hold
  [ok  ] AT_RANDOM and AT_PLATFORM are different places on the stack
  [ok  ] AT_EXECFN names the file the kernel actually ran
  [ok  ] AT_SYSINFO_EHDR == the base of the [vdso] mapping
  [ok  ] AT_SECURE == 0 (not a setuid run)  -- value 0
  [ok  ] AT_UID == getuid()  -- auxv 1000, getuid 1000
  [ok  ] AT_MINSIGSTKSZ is a SIZE and stays plausible  -- 3376 bytes
  18/18 checks passed
</pre>
                </div>
                <p>Line three is the one to build first in any parser like this. <strong>Two numbers that must be equal for a reason that is not &ldquo;they came from the same place&rdquo;.</strong> The left is the kernel&rsquo;s translation of the file into memory; the right is the file&rsquo;s own layout. If the kernel were doing anything other than loading this file at one base, they would differ &mdash; and if a future kernel changed how it builds the process image, this is the line that would catch it.</p>
                <p>Lines four and five close the loop in the other direction, and they are the ones that make &ldquo;the kernel is telling the truth&rdquo; a stronger statement than it looks. <strong>Take the kernel&rsquo;s <code>AT_ENTRY</code>, find the mapping that contains it, compute its offset within that mapping, add the mapping&rsquo;s file offset, and you have a file offset.</strong> That is a number the kernel never gave you, derived through two hops, and it must equal <code>e_entry</code> &mdash; which the script read from a completely different structure. Kernel &rarr; address &rarr; mapping &rarr; file offset &rarr; the number in the file.</p>
                <p>And note what the script does <em>not</em> do: it never shells out to <code>readelf</code>. It parses the 64-byte ELF header itself, with <code>struct.unpack_from</code>. <strong>That is deliberate and it is the mission of this collection in one line</strong> &mdash; the tool is the oracle, and the format is the subject. A crosscheck that used <code>readelf</code> to verify <code>readelf</code>&rsquo;s fields would prove that <code>readelf</code> is consistent with itself.</p>
                <p>Finally, the harness that keeps all of it honest:</p>
                <div class="hex-dump">
                    <pre>$ python3 crosscheck.py 2&gt;&amp;1 | tail -13
  G1   12 passed   0 failed      the auxv exists
  G2    5 passed   0 failed      auxv vs the ELF file
  G3    3 passed   0 failed      AT_BASE is another file
  G4    7 passed   0 failed      the vDSO is a real ELF
  G5    5 passed   0 failed      mmap_min_addr
  G6    3 passed   0 failed      demand paging
  G7    5 passed   0 failed      the process map
  G8    1 passed   0 failed      the artifact, end to end
  41/41 checks passed
  ALL CLAIMS HOLD
</pre>
                </div>
                <p>Group G8 runs <code>stackwalk.py</code> as a subprocess and requires exit 0. <strong>So the harness is not a parallel description of the artifact &mdash; it is a test of it</strong>, and the two cannot drift apart without a failure. This is the last piece, and it is the piece that makes the other five courses&rsquo; claims checkable too: a claim is not &ldquo;measured&rdquo; until something re-measures it.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Try It Yourself</h2>
                <div class="hex-dump">
                    <pre>$ cd courses/img/assets/samples
$ ./build_samples.sh                    # from empty
$ python3 stackwalk.py                 # the artifact
$ python3 stackwalk.py -v              # with the raw random bytes
$ python3 crosscheck.py                # all 41 claims
$ python3 stackwalk.py --dump          # decoded, no assertions
</pre>
                </div>
                <p>Then make it fail, which is the only real test of a checker:</p>
                <div class="hex-dump">
                    <pre>  1. Make stackwalk.py lie. Change the
     AT_ENTRY - AT_PHDR check to compare
     against e_entry + e_phoff and run it.
     (The check fails, crosscheck reports 40/41
     and exits non-zero, and the build script
     shows the failure. A checker that has never
     failed is not known to work.)

  2. Make the KERNEL's data wrong instead.
     Add an AT_PHNUM of 15 to the raw bytes in
     imgdump's output before parsing. The check
     against e_phnum catches it immediately.
     (This is the check's real purpose: not to
     confirm the parser, but to catch a
     disagreement.)

  3. Now break the FILE side: corrupt byte 24
     of imgdump -- the low byte of e_entry --
     with dd. The auxv still says the old
     address, the file now says something else,
     and TWO checks fail: the difference check
     and the offset check. (Two failures for one
     corruption is the right answer, and seeing
     which ones is how you learn what each is
     actually testing.)

  4. Add a check stackwalk.py does not have:
     assert that AT_PHNUM * AT_PHENT + AT_PHDR
     does not overflow, and that the program
     header table is inside a read-only region.
     Then break a PT_LOAD's p_flags in the file
     to be writable and see whether the memory
     check catches it. (It will not -- /proc
     reports the KERNEL's permissions, not the
     file's. Write down what that means: the
     kernel is trusted here, and a parser that
     wants to verify the FILE must read the
     file.)

  5. Finally, run the whole thing under
     valgrind ./imgdump, and then under
     "setarch -R". Everything must still pass.
     (It will: none of the checks assume a
     particular address, only relationships. A
     check that depends on an absolute address
     is testing the randomiser, not the parser.)
</pre>
                </div>
                <p>Exercise 4 is the sharpest one in the course, and its answer is a real limitation rather than a triumph. <strong><code>/proc/&lt;pid&gt;/maps</code> reports the permissions the kernel applied, which came <em>from</em> the file &mdash; so a check that compares the map against the file&rsquo;s <code>p_flags</code> is not independent, it is circular.</strong> The honest resolution is that verifying the <em>file</em> requires reading the file, and the script does that separately with <code>parse_elf64</code>. <strong>Knowing which of your two sources is derived from which is the difference between a crosscheck and a tautology</strong>, and every claim in this course was chosen so that the two sides come from genuinely different places.</p>
                <p>Exercise 5 is the last discipline and it is the one that keeps the tool useful. <strong>Every check is a relationship, so all eighteen survive <code>setarch -R</code> and a valgrind run without modification.</strong> A parser that only works at one address, or only outside an instrumentation tool, is a parser that works on your machine once. Being able to say &ldquo;and it still passes with ASLR off&rdquo; is a small thing that separates a script you ran from a tool you trust.</p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>This is the concept that completes the chain, and the completion is worth stating plainly. The mission of this collection is parsing &rarr; a working executable, without depending on a tool that already knows the answer. <strong>This course ends with a program that reads the running process&rsquo;s own description of itself, using no tool, and verifies every field against the file the kernel loaded.</strong> That is the same shape as reading a program header table in <a href="/courses/elf/lessons/program-header-table">module one of the ELF course</a>, with the file replaced by a live kernel and the header replaced by an array on a stack.</p>
                <p>The forward dependency is exact. <a href="/courses/dyn/lessons/dyn-resolve">Rebuilding the Scope Yourself</a> asks the reader to read <code>DT_NEEDED</code> out of a running process and walk the loader&rsquo;s search order &mdash; and the first thing that exercise needs is <code>AT_PHDR</code>, which is what this artifact produces. <strong>So the dyn course&rsquo;s hardest exercise is this course&rsquo;s starting point, and the two are one artifact at two layers.</strong> That is the chain working as the mission describes it: a course must neither require a link the reader has not been given, nor re-teach a neighbour.</p>
                <p>The connection back to the <a href="/courses/reloc/lessons/reloc-why-so-many">relocations course&rsquo;s central measurement</a> is the deepest one. That course proved the same source needs <strong>one</strong> relocation per datum on x86-64 and <strong>two</strong> on AArch64, checked programmatically. This course shows why the difference exists: on AArch64 the address is a 64-bit quantity formed from two instructions far apart, while the kernel here hands the program a single already-computed base. <strong>The kernel&rsquo;s choice of what to put in the auxv is what makes one relocation enough</strong> &mdash; if the kernel handed over a page number and an offset separately, every datum would need two. The ABI choices of two different machines fall out of the same design pressure, and this is the layer where you can see it.</p>
                <p>Two connections to the platform itself, since this course ends the executable chain. <strong>The <a href="/courses/link/lessons/link-write-script">linker-script concepts</a> taught <code>ld --verbose</code> as a file you can edit</strong>, and the <code>PT_LOAD</code> rows that script emits are the requests this course watched the kernel grant. And the <a href="/courses/macho/lessons/macho-dyld">Mach-O loader concept</a> in the sibling course covers the same kernel job on a different kernel &mdash; <code>dyld</code> reads a load command instead of a program header table, and gets the same information by a different route, because the kernel still has to tell it where everything landed.</p>
                <p>And the honest note about where this stops. <strong>There is no kernel source in this course</strong>, and the <code>research.md</code> says so. Every claim here is observational: the auxv was measured, the vDSO was read, the floor was found, the fault counts were counted. <em>Why</em> the kernel chose 64 KB as its floor is explained from the attack it prevents, not from the code that implements it. <strong>That distinction is the course&rsquo;s own discipline applied to itself</strong>, and it is stated in the research log rather than hidden, because a claim that has not been verified should be visible as unverified rather than quietly smoothed over into prose.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/img/lessons/img-place">Previous: Where the Kernel Put Everything</a></span>
                <span>Next: <a href="/courses/dyn/lessons/dyn-resolve">Continue: Rebuilding the Scope Yourself</a></span>
            </div>
        </div>


    render_lesson_js(&mut page)
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
