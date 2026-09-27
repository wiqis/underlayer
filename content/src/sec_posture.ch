// Executable Security and Hardening — Module 4: Read It Yourself
// Concept: parse every feature out of the file, and know which source each check read.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_sec_posture() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Reading a Binary's Posture — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson sec-lesson">
            <a href="/courses/sec" class="back-link">Back to course</a>
            <h1>Reading a Binary's Posture</h1>
            <div class="lesson-meta">25 min &middot; Module 4: Read It Yourself &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Six concepts, one artifact, and a habit. The artifact is a reader: given a binary and no build system, it reports what hardening the file actually contains. <strong>It does not use <code>readelf</code>, <code>objdump</code>, or a compiler</strong> &mdash; it parses the ELF header, the program headers, the section table, the dynamic array, the string table and a note, with <code>struct.unpack_from</code> and nothing else.</p>
                <div class="hex-dump">
                    <pre>$ cd courses/sec/assets/samples
$ python3 harden.py relro_partial
  ET_EXEC, EM_X86_64, 14 program headers, 30 sections
  stack executable?                  no   [PT_GNU_STACK flags RW-]
  RELRO region                       0x403df8..0x404000
  RELRO tier                         partial
    .got.plt section                 present
    covered by RELRO                 NO
    ends on a page                   yes
  writable text (TEXTREL)            no
  stack canary refs (%fs:0x28)       0
  FORTIFY _chk imports               none
  CET IBT (indirect branch tracking) False
  CET SHSTK (shadow stack)           False
  endbr64 instructions in the file   6
  position independent               NO (ET_EXEC)
  6/10 checks
  WEAKNESSES: NOT PIE, partial RELRO only, no stack canary
</pre>
                </div>
                <p>And the line that makes it a tool rather than a demo is the fourth from the bottom: <strong><code>covered by RELRO: NO</code></strong>. Not &ldquo;partial&rdquo;, which is a label the file claims about itself, but the geometric fact that the GOT section does not fit inside the sealed range.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Every feature this course measured leaves its trace in a different part of the file, and the whole design of a posture reader follows from taking that seriously.</p>
                <div class="formula">
  what to check        where the answer is   how it is stored
  ------------------   -------------------   ---------------
  stack executable?    PT_GNU_STACK          1 bit in a flag
  RELRO tier           PT_GNU_RELRO          a range
                       + DT_FLAGS            a claimed bit
  GOT actually sealed  section table         GEOMETRY
                       vs PT_GNU_RELRO
  TEXTREL              DT_TEXTREL            a tag
  stack canary         the instruction        BYTE PATTERN
                       stream
  FORTIFY              DT_STRTAB             an IMPORT NAME
  CET                  PT_GNU_PROPERTY       a nested note
  PIE                  e_type                2 bytes

  notice the pattern. only TWO of these are
  a single bit or byte in a fixed place. the
  rest need the file's geometry, or its
  string table, or a byte search.
                </div>
                <p>That pattern is the reason &ldquo;read the hardening flags&rdquo; is not a method. <strong>Two of eight features are bits, and they are the two easiest to get wrong</strong> &mdash; because a bit is a promise and a byte pattern is a fact. A posture tool that reads only bits reports what a binary <em>says</em> about itself; one that also does the geometry and the searches reports what it <em>contains</em>.</p>
                <p>So the artifact has two kinds of check and the distinction is deliberate:</p>
                <div class="formula">
  CLAIMED   a bit, a tag, a note.
            cheap, fast, and exactly as
            trustworthy as the producer.

  PROVEN    the geometry, the coverage, the
            instruction count, the import list.
            costs a parse, and cannot be
            satisfied by setting a bit.

  a report that only has CLAIMED checks is
  an echo. the interesting rows are the
  PROVEN ones, and they are the ones this
  course spent its concepts on.
                </div>
            </div>

            <div class="unit unit-reality">
                <h2>Why Each Check Names Its Source</h2>
                <p>Every line of the report says where its answer came from, and that is not decoration. <strong>A check that reads the same byte twice and calls it two checks is worse than no check</strong>, because it agrees with a wrong answer and you have no way to tell. This is the same trap the image course walked into with <code>/proc/self</code> in a pipeline, and the same one the RELRO concept hit when the tier said &ldquo;full&rdquo; and the geometry said otherwise.</p>
                <div class="formula">
  the checks, and whether each is
  INDEPENDENT of the others or not:

    e_type          -> ELF header
    PT_GNU_STACK    -> segment table      ] different
    DT_TEXTREL      -> dynamic array      ] tables,
    DT_STRTAB       -> string table       ] and they
    PT_GNU_PROPERTY -> note               ] can
    .got.plt        -> section table      ] DISAGREE
    PT_GNU_RELRO    -> segment table      ]
    %fs:0x28        -> instruction bytes  ] not a
    endbr64         -> instruction bytes  ] table at
    __*_chk         -> string table       ] all

  the cross-TABLE comparisons are the
  valuable ones. "the note says IBT" and
  "there are endbr64" are two facts about
  two different structures, and a mismatch
  between them is a real finding rather than
  a redundancy.
                </div>
                <p>And the <code>--explain</code> output says all of this in one screen, because a tool whose reasoning is invisible is a tool you have to take on faith &mdash; which is the thing this course exists to stop doing.</p>
                <div class="hex-dump">
                    <pre>$ python3 harden.py --explain
  Each check names the SOURCE it read. A report that reads one byte twice
  and calls it two checks is worse than no report, so the sources here are
  deliberately different parts of the file:
    stack executable?   PT_GNU_STACK flags          (segment table)
    RELRO tier          PT_GNU_RELRO + DT_BIND_NOW  (segment + dynamic)
    RELRO covers GOT?   section table vs segment    (two different tables)
    TEXTREL             DT_TEXTREL                  (dynamic array)
    stack canary        %fs:0x28 in the bytes       (instruction stream)
    FORTIFY             DT_STRTAB                   (string table)
    CET                 PT_GNU_PROPERTY             (note)
    PIE                 ELF header e_type           (the header itself)
  The canary check is the one that surprises people: it is a byte pattern,
  not a flag, because the stack protector leaves no trace in any header. The
  same is true of FORTIFY -- its trace is an IMPORT, not a bit.
</pre>
                </div>
                <p>The last two lines are the ones to keep. <strong>The stack protector and FORTIFY both leave no header field at all</strong>, so a tool built on the assumption that hardening is a set of flags will report &ldquo;unknown&rdquo; for two of the most widely deployed features in the world. That is not a limitation of the tool; it is a fact about the features, and finding it out is the argument for reading the file rather than the documentation.</p>
            </div>

            <div class="unit unit-example">
                <h2>Running It On Things You Did Not Build</h2>
                <p>The real use is not your own binaries. It is everything else:</p>
                <div class="hex-dump">
                    <pre>$ python3 harden.py /usr/bin/ls /usr/lib/x86_64-linux-gnu/libc.so.6
$ python3 harden.py --json mx_all | python3 -m json.tool
$ for f in build/*; do python3 harden.py "$f" | tail -1; done
</pre>
                </div>
                <p>Three uses, in increasing order of value. <strong>Auditing a dependency</strong> &mdash; you did not build it, so your build flags mean nothing to it, and the only evidence is the file. <strong>Comparing two builds</strong> &mdash; the H7 matrix in the build script is exactly this, and it is how the clang/gcc divergence was found. <strong>Failing a build</strong> &mdash; and this is the one that pays for itself, because hardening flags regress silently.</p>
                <p>Nobody removes <code>-z now</code> on purpose. A link line gets rebuilt from variables, one flag falls out, and the binary still compiles, still runs, and is quietly weaker. <strong>The symptom of that change is not a build failure, so it needs a test rather than a review.</strong> The artifact exits non-zero, prints a <code>WEAKNESSES</code> line naming what is missing, and a CI job can gate on it.</p>
                <p>One thing the report deliberately does not do, which is worth naming because every hardening tool eventually gets asked to. <strong>It does not produce a score.</strong> &ldquo;7 out of 10 hardened&rdquo; invites trading one feature for another, and the features are not commensurable &mdash; RELRO is nearly free, <code>-z now</code> costs startup time, CET is all-or-nothing across a whole process, and the canary catches a specific bug class. A list of named properties with their sources is honest. A number is a category error wearing a decimal point.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Try It Yourself</h2>
                <div class="hex-dump">
                    <pre>$ cd courses/sec/assets/samples
$ ./build_samples.sh
$ python3 harden.py --explain
$ python3 harden.py drv_gcc drv_clang mx_all mx_plain
$ python3 crosscheck.py 2&gt;&amp;1 | tail -14
</pre>
                </div>
                <p>Then do the thing that turns it into a habit:</p>
                <div class="hex-dump">
                    <pre>  1. Run it on a binary you did not build and
     compare with what its documentation
     claims. Pick a system library:
       python3 harden.py /usr/lib/x86_64-linux-gnu/libc.so.6
     Does the distribution's hardening page
     agree? Any disagreement is either a
     documentation bug or a per-package
     exception, and both are worth knowing.

  2. Now prove the tool can fail. Break a
     claim it makes and check the crosscheck
     notices:
       python3 -c "
       import re
       s = open('harden.py').read()
       s = s.replace('(lo + sz) &lt;= hi', 'True')
       open('/tmp/h2.py','w').write(s)"
       python3 /tmp/h2.py relro_partial
     (The coverage check now claims YES for a
     binary where it is NO, and nothing catches
     it -- because you changed the CHECK, not
     the data. A checker that has never failed
     is not known to work. Break the DATA
     instead and confirm the check fires.)

  3. Add a check the tool does not have. A
     good one: does every PT_LOAD that is
     writable have a corresponding page inside
     the RELRO range, and is every
     .data.rel.ro section inside it? That is
     the W^X concept's positive check, and it
     catches a linker that emits the section
     outside the sealed range.

  4. Make the report answer a question it
     currently cannot. "Is this binary at least
     as hardened as that one?" requires
     comparing two reports, and the naive
     version counts features. The honest
     version asks, per feature, whether the
     state changed -- and that is a PARTIAL
     ORDER, not a number, because a binary
     can be better in one row and worse in
     another. Try it. The absence of a total
     order is the finding.

  5. Finally, the exercise that is really the
     course: take a hardening CLAIM from a
     project you work on -- a README, a CI
     config, a wiki -- and check it against a
     binary that project produced. Write down
     every claim that does not hold, and for
     each one, name which of the three layers
     from sec-defaults it belongs to. (That
     last step is the whole course in one
     question: a false claim about hardening is
     almost never a mistake about security.
     It is a mistake about which tool decided
     what.)
</pre>
                </div>
                <p>Exercise 4 has the most interesting answer and it is a result rather than an exercise. <strong>Hardening properties are only partially ordered.</strong> A binary can be stronger than another in RELRO and weaker in FORTIFY, and neither dominates &mdash; so &ldquo;is this at least as hardened&rdquo; has no total-order answer, only a per-row comparison. That is the formal reason the tool refuses to emit a score, and it is a better reason than &ldquo;scores are bad&rdquo;. A number would have to invent a weighting the properties do not support, and the weighting would be the tool author&rsquo;s opinion dressed as a measurement.</p>
                <p>Exercise 5 is the one that makes the course pay off, and it is worth doing slowly. <strong>Every false hardening claim you find belongs to one of three layers</strong> &mdash; codegen, linker, or driver &mdash; and naming the layer tells you where to look and who can fix it. A claim about the canary is a codegen question. A claim about <code>-z now</code> is a link-line question. A claim that &ldquo;our builds are hardened by default&rdquo; is almost always a driver question, and it is the one nobody owns.</p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>This concept is the payoff for the chain, and the connection runs the full length of it. <a href="/courses/elf/lessons/program-header-table">The program-header concept</a> taught the segment table. <a href="/courses/elf/lessons/section-header-table">The section-header concept</a> taught the section table and the string table index. <a href="/courses/elf/lessons/dynamic-section">The dynamic-section concept</a> taught <code>DT_*</code> tags and the rule that the array is 16 bytes per entry. <strong>Every one of those is a source this artifact reads, and it reads them with <code>struct.unpack_from</code> rather than shelling out.</strong> That is the mission stated as a program: a format, parsed by hand, into a working executable, with no dependency on the tool that already understands it.</p>
                <p>The connection to the <a href="/courses/img/lessons/img-walk">image-loading course&rsquo;s artifact</a> is structural and it is the strongest argument for the whole collection. That artifact is a reader too &mdash; of a process image rather than of a file &mdash; and it made the same discipline its centre: <strong>every value checked against a source that did not produce it.</strong> Here the sources are the segment table, the section table, the dynamic array, the string table, a note, and the instruction stream. Two courses, two artifacts, one rule, and the rule is the thing worth carrying out of this collection rather than any individual finding.</p>
                <p>Two connections that are about what the tool cannot see. <a href="/courses/sec/lessons/sec-cet">The CET concept</a> established that the shadow-stack half is configured by the loader through the thread control block, so reading the binary does not settle whether the property holds &mdash; and this report says so rather than printing a confident <code>False</code>. And <a href="/courses/img/lessons/img-auxv">the auxv concept</a> established that the canary&rsquo;s per-thread secret comes from kernel-supplied randomness, so <code>%fs:0x28</code> is a <em>count</em> and not a <em>check</em>: this tool can say a binary has three tripwires and cannot say the value is unpredictable. <strong>Two features where the file is genuinely not the whole story, both stated as limits instead of guessed at.</strong></p>
                <p>And the connection forward, which is the next course in the list. <strong>Everything measured here is a mitigation, and mitigations are inputs to a policy.</strong> Knowing that clang defaults the stack protector off, that <code>-z now</code> is the difference between a sealed and an unsealed GOT, and that FORTIFY does not touch heap buffers is what makes a defensible hardening policy writable &mdash; because a policy that says &ldquo;enable all the flags&rdquo; is not a policy, it is a superstition with a build script. The next course is about turning these measurements into one, and it can only do that because this one established what each switch actually does.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/sec/lessons/sec-cet">Previous: CET: The Instructions Are Not the Request</a></span>
                <span>Next: <a href="/courses/img/lessons/img-auxv">Back to the chain: The Auxiliary Vector</a></span>
            </div>
        </div>


    render_lesson_js(&mut page)
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
