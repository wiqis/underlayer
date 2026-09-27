// Executable Security and Hardening — Module 3: Permissions
// Concept: endbr64 is present whether or not the binary asks for enforcement,
// and the note is what counts.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_sec_cet() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("CET: The Instructions Are Not the Request — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson sec-lesson">
            <a href="/courses/sec" class="back-link">Back to course</a>
            <h1>CET: The Instructions Are Not the Request</h1>
            <div class="lesson-meta">23 min &middot; Module 3: Permissions &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Control-flow Enforcement Technology is the newest feature in this course and the only one where the obvious measurement is wrong. The obvious measurement is &ldquo;does the binary contain <code>endbr64</code>&rdquo;. <strong>Measured on a binary built with protection explicitly disabled, the answer is yes &mdash; five of them.</strong></p>
                <div class="hex-dump">
                    <pre>$ cd courses/sec/assets/samples &amp;&amp; ./build_samples.sh 2&gt;&amp;1 | sed -n '/H6/,/H7/p'
  the property note -- what the binary ASKS the hardware for:
   none    note=0x00000010   properties: x86 ISA needed: x86-64-baseline
   branch  note=0x00000020   properties: x86 feature: IBT
   full    note=0x00000020   properties: x86 feature: IBT, SHSTK

  endbr64 in the binary, and in MY functions only:
   none    total=5   in main/helper=0
   branch  total=7   in main/helper=1
   full    total=7   in main/helper=1
</pre>
                </div>
                <p>Look at the first row carefully. <strong>Protection off. Five <code>endbr64</code> in the binary, zero in <code>main</code> or <code>helper</code>, and a property note that claims nothing but the instruction set.</strong> Those five come from somewhere else entirely, and finding out where is the best single result in this course.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>CET has two independent halves, and they are enforced by two different mechanisms:</p>
                <div class="formula">
  IBT   INDIRECT BRANCH TRACKING

    the attack: overwrite a function POINTER,
    so an indirect call goes somewhere you
    chose.

    the defence: every legitimate branch
    target BEGINS with a landing pad.

        endbr64          f3 0f 1e fa
                         a NOP on old CPUs

    so a misdirected indirect branch lands
    on something that is not a landing pad,
    and the CPU faults.

    enforcement: the CPU checks that the
    TARGET of an indirect branch starts with
    endbr64. that is HARDWARE.

  SHSTK  SHADOW STACK

    the attack: overwrite a RETURN ADDRESS.

    the defence: the return address is also
    kept in a second stack the program cannot
    address with an ordinary write.

        a write updates the normal stack
        and NOT the shadow stack
        return compares the two
        mismatch -> fault

    enforcement: the CPU maintains a second
    stack, and the LOADER turns it on by
    writing the shadow stack configuration
    into the thread control block.

  so SHSTK is configured by the LOADER, and
  IBT is configured by the CPU reading a
  NOTE in the binary. different switches.
                </div>
                <p>And that is the whole reason the obvious measurement fails. <strong><code>endbr64</code> is a compile-time instruction; enforcement is a load-time decision made from a different part of the file.</strong> A binary can be full of landing pads and request nothing, in which case the hardware will not check them. Or &mdash; and this is the subtle direction &mdash; a binary could request IBT with a note and contain no <code>endbr64</code> at all, in which case the hardware would fault on every indirect call.</p>
                <div class="formula">
  the instruction is NECESSARY.
  the note is SUFFICIENT.

  neither implies the other on its own, and
  the security property needs both:

    instruction present + note absent
        -> no enforcement. SAFE BUT USELESS.
           the landing pads are just NOPs.

    instruction absent + note present
        -> the program crashes immediately.
           BROKEN BUT LOUD.

    both present
        -> the property holds.
                </div>
                <p>So a posture report has to check the note, and an instruction count is at best a secondary signal. That is not a quibble about a tool. <strong>It is the difference between a binary that is protected and a binary that is prepared to be protected.</strong></p>
            </div>

            <div class="unit unit-reality">
                <h2>Where the Five <code>endbr64</code> Come From</h2>
                <p>The obvious follow-up is to ask which functions they are in, and the answer is the useful one:</p>
                <div class="hex-dump">
                    <pre>$ ./build_samples.sh 2&gt;&amp;1 | sed -n '/H6/,/H7/p'
  with protection OFF my functions have none, yet the binary still
  has 5. They come from the C runtime, which the distro built with
  protection ON:
     crt1.o    endbr64 = 2
     crti.o    endbr64 = 2
     crtn.o    endbr64 = 0
</pre>
                </div>
                <p><strong><code>crt1.o</code> and <code>crti.o</code> ship pre-hardened.</strong> They are the C runtime startup files &mdash; <code>_start</code>, <code>register_tm_clones</code>, <code>__do_global_dtors_aux</code>, <code>frame_dummy</code>, <code>_init</code>, <code>_fini</code> &mdash; and the distribution built them with CET enabled, months or years before this compiler existed.</p>
                <p>So the consequence is worth stating as a rule: <strong><code>-fcf-protection=none</code> removes the protection from your code and leaves the startup files alone.</strong> You cannot un-harden the C runtime with a compiler flag, because the C runtime was compiled separately and is linked in as an object file you did not build. And that is the correct default &mdash; it means the process entry path is protected regardless of what your build does.</p>
                <p>Now the note itself, which is the check that matters:</p>
                <div class="hex-dump">
                    <pre>$ readelf -n cet_none | sed -n '/GNU_PROPERTY/,/^$/p'
    GNU                  0x00000010	NT_GNU_PROPERTY_TYPE_0
        Properties: x86 ISA needed: x86-64-baseline

$ readelf -n cet_full | sed -n '/GNU_PROPERTY/,/^$/p'
    GNU                  0x00000020	NT_GNU_PROPERTY_TYPE_0
        Properties: x86 feature: IBT, SHSTK
  	x86 ISA needed: x86-64-baseline
</pre>
                </div>
                <p>Two things to read here. <strong>The note grows from <code>0x10</code> to <code>0x20</code> bytes</strong> when a feature is claimed, which is a coarse but reliable signal &mdash; and a coarse signal is better than none, because a fixed-size expectation is what a parser can assert on. <strong>And the ISA requirement is present in both.</strong> That is a different property: it says &ldquo;this binary needs at least x86-64-baseline&rdquo;, which is a compatibility statement rather than a hardening one, and the two live in the same note for the same reason &mdash; both are things the loader needs to know before running the binary.</p>
                <p>The instruction itself, for completeness:</p>
                <div class="hex-dump">
                    <pre>$ objdump -d cet_full | grep -A1 '&lt;main&gt;:' | tail -1
    1130:	f3 0f 1e fa          	endbr64
</pre>
                </div>
                <p><code>f3 0f 1e fa</code>. On a CPU without CET it decodes as a four-byte <code>NOP</code> with an unusual prefix, so a binary full of landing pads still runs on old hardware &mdash; which is what makes the feature deployable at all, and is the same design choice as the <code>NX</code> bit being honoured only on hardware that has it.</p>
            </div>

            <div class="unit unit-example">
                <h2>Parsing the Note</h2>
                <p>The note is a nested structure, and the nesting is the interesting part. Three levels, each with its own alignment rule:</p>
                <div class="formula">
  PT_GNU_PROPERTY points at a note:

    namesz descsz type  name  descriptor
    |      |      |     |     |
    |      |      |     |     +-- the x86 property array
    |      |      |     +-------- "GNU\0" padded to 4
    |      |      +-------------- 5 = NT_GNU_PROPERTY_TYPE_0
    |      +--------------------- the descriptor length
    +---------------------------- the name length

  and the descriptor is ITSELF an array of
  (type, size, value...) triples:

    pr_type   pr_datasz   the 32-bit value
    --------  ----------  ------------------
    c0000002  00000004    0x3  = IBT | SHSTK
                ^^^^^^^^    ^^^

  so "IBT and SHSTK" is ONE property whose
  value is a BITMASK, not two properties.
  and the size must be >= 4 or there is no
  value to read.
                </div>
                <p>Two things there are load-bearing and both were learned the hard way by the artifact. <strong>Each triple&rsquo;s size field is rounded up to 8 for the next entry</strong>, so stepping by the declared size rather than the rounded size desynchronises the walk. And <strong>a triple with size 0 advances the cursor by nothing</strong>, which is an infinite loop &mdash; and which is exactly what <code>harden.py</code> did on its first run against a real binary, hanging with no output at all.</p>
                <p>That bug is worth more than the parser, because it is a category. <strong>Any loop whose step is computed from the data it is reading can fail to advance, and the failure mode is a hang rather than an error.</strong> For a security tool a hang is arguably the worst outcome available: not a wrong answer, but no answer, and a CI job that hangs looks like infrastructure trouble rather than a parse bug. The fix is to make the step unconditionally positive, and the fix is in the code with a comment explaining why, because the next person to simplify it will reintroduce the hang.</p>
                <div class="formula">
  step = (psize + 7) &amp; ~7        # round up to 8
  if step == 0: step = 8            # NEVER zero
  o += step

  the second line is not defensive
  programming. it is a documented bug
  that this parser had, and removing the
  guard removes the bug.
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Try It Yourself</h2>
                <div class="hex-dump">
                    <pre>$ cd courses/sec/assets/samples
$ ./build_samples.sh 2&gt;&amp;1 | sed -n '/H6/,/H7/p'
$ python3 harden.py cet_none cet_full
$ python3 crosscheck.py 2&gt;&amp;1 | sed -n '/H6/,/H7/p'
</pre>
                </div>
                <p>Then separate the two things the concept separates:</p>
                <div class="hex-dump">
                    <pre>  1. Build the four combinations by hand and
     observe what each does:
       -fcf-protection=none,   note stripped
       -fcf-protection=none,   note present
       -fcf-protection=branch, note stripped
       -fcf-protection=branch, note present
     (Stripping the note from a CET build is a
     few bytes of objcopy. Then RUN all four.
     The "instructions but no note" one runs
     perfectly -- unprotected. The "note but no
     instructions" one, if the CPU enforces IBT,
     faults on the first indirect call. This is
     the clearest demonstration in the course
     that the two mechanisms are independent.)

  2. Count endbr64 per FUNCTION rather than per
     binary, and list the functions that have
     none in a CET build. Any? (On this build,
     no -- but on a mixed-toolchain one, yes: an
     object compiled by an older compiler and
     linked into a CET binary is a hole. That
     is what a linker script and a hardened
     CI check are for.)

  3. Read the note of a real system binary:
       readelf -n /usr/bin/ls | grep -A2 GNU_PROPERTY
     Does your distribution's libc request CET?
     Does /usr/bin/ls? If the libc does and the
     binary does not, that is a deliberate
     choice -- enforcement requires EVERY object
     to comply, so a partial rollout is worse
     than none.

  4. Check whether the CPU you are on supports
     it at all:
       grep -o 'ibt\|shstk' /proc/cpuinfo | sort -u
     (An empty result means the note is a
     request the hardware will ignore. The
     binary is still correct; the property is
     simply not enforced on this machine. A
     report should distinguish "not requested"
     from "requested and not available", and
     most do not.)

  5. Finally: the shadow stack half has not been
     measured in this course at all. Find out
     whether your kernel supports it, read what
     the loader does, and decide whether to
     claim anything. (The honest answer here is
     "not measured" -- SHSTK is configured through
     the thread control block rather than the
     note, so the binary is not the whole story
     and reading it would not settle it.)
</pre>
                </div>
                <p>Exercise 1 is the one that makes the independence argument real rather than rhetorical, and stripping a note with <code>objcopy</code> is a five-minute experiment with a genuinely surprising result. <strong>A binary with every landing pad in place and no note runs perfectly, and is completely unprotected.</strong> Anyone who has counted <code>endbr64</code> as a hardening metric has measured nothing, and the experiment makes that unarguable in a way that prose cannot.</p>
                <p>Exercise 3 is the deployment lesson, and it is the reason this feature is harder to roll out than RELRO. <strong>Enforcement requires <em>every</em> object in the process to comply</strong> &mdash; the binary, every shared library, the C runtime. A partial rollout is not a partial protection; it is either inert (nobody requests it) or broken (something requests it and something else does not comply). That all-or-nothing property is why CET adoption is a distribution decision rather than a per-project one, and it is a good contrast with <code>-z now</code>, which is entirely local to one binary.</p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>The connection to <a href="/courses/img/lessons/img-auxv">the auxiliary vector concept</a> is the deepest one in the course and it is worth spelling out, because it is a different enforcement path for the same class of property. <strong>That concept measured <code>AT_HWCAP</code> and the capability bitmask, and noted that a program should use it rather than parse <code>/proc/cpuinfo</code>.</strong> Here is a property where the hardware capability and the binary&rsquo;s request are <em>different</em> files: the CPU publishes what it can do, the binary publishes what it wants checked, and the loader configures the shadow stack using both. CET is therefore not one mechanism but three cooperating decisions in three different places, and the <a href="/courses/sec/lessons/sec-posture">posture concept</a> can only see the middle one from the file.</p>
                <p>The connection to <a href="/courses/reloc/lessons/pic-violation">the PIC-violation concept</a> is about what CET does <em>not</em> fix. That concept measured the cost of position independence and the <code>R_X86_64_32S</code> overflow at <code>0x80000000</code>. <strong>CET&rsquo;s shadow stack stops a corrupted return address; IBT stops a corrupted function pointer. Neither stops a corrupted data pointer that is dereferenced rather than called.</strong> So a full CET deployment still leaves data-only attacks untouched, and the mitigation for those is what <a href="/courses/sec/lessons/sec-canary">the canary</a> and RELRO do. Four mechanisms, four different attack shapes, and the honest summary is that hardening is a set of partial mitigations rather than a single switch &mdash; which is the correct mental model and the reason this course is seven concepts rather than one.</p>
                <p>Two connections to close the course. <a href="/courses/elf/lessons/elf-header-fields">The ELF header-fields concept</a> taught that every field has a job, and CET is a nice late example of a field that exists because <em>the file is not the only thing that matters</em> &mdash; the same reason <code>AT_BASE</code> exists. And <a href="/courses/img/lessons/img-entries">The image course&rsquo;s pointer-versus-size warning</a> is directly relevant to a parser of this note: <strong>a property descriptor is a bitmask in a <code>uint32</code> and you must know which bits mean what</strong>, exactly as <code>AT_PAGESZ</code> is a size that looks like an address. A parser that reads the property value as a boolean is wrong in a way that a type system cannot catch, because the format gives you no way to tell.</p>
                <p>One limit, stated rather than buried. <strong>The shadow-stack half of CET is not measured in this course.</strong> The property note carries the request, but SHSTK enforcement is configured by the loader through the thread control block, so reading the binary does not settle whether the property holds. Exercise 5 hands that to the reader with the reason written down, because a course that claimed it would be claiming something its own instrument cannot see.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/sec/lessons/sec-wx">Previous: W^X, and Why TEXTREL Died</a></span>
                <span>Next: <a href="/courses/sec/lessons/sec-posture">Reading a Binary's Posture</a></span>
            </div>
        </div>


    render_lesson_js(&mut page)
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
