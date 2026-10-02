// Executable Security and Hardening — Module 2: The GOT
// Concept: the page arithmetic that leaves eight bytes writable, and why -z now
// is what makes sealing possible at all.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_sec_relro() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Two Tiers of RELRO — Underlayer")
    page.appendTitle(&title)

    render_lesson_nav(&mut page)
    render_lesson_css(&mut page)

    #html {
        <div class="lesson sec-lesson">
            <a href="/courses/sec" class="back-link">Back to course</a>
            <h1>The Two Tiers of RELRO</h1>
            <div class="lesson-meta">24 min &middot; Module 2: The GOT &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>RELRO is mentioned eight times across the concept files written before this one, and <strong>the words &ldquo;partial RELRO&rdquo; and &ldquo;full RELRO&rdquo; appear in none of them.</strong> That is the gap. Almost every reference to RELRO treats it as a thing you either have or do not have, and it is neither: it is a range, and the question is how far the range reaches.</p>
                <p>The consequence is not academic. The <a href="/courses/dyn/lessons/dyn-bind-time">dynamic linking course</a> measured that <code>.got.plt</code> disappears under <code>-z now</code> and said so without saying why. <strong>The why is that under lazy binding the loader still has to <em>write</em> the resolved address into that slot</strong> &mdash; so the page holding it cannot be read-only, and partial RELRO cannot cover it. The eight writable bytes are not an oversight. They are the loader&rsquo;s workspace.</p>
                <div class="hex-dump">
                    <pre>$ cd courses/sec/assets/samples &amp;&amp; ./build_samples.sh 2&gt;&amp;1 | sed -n '/H3/,/H4/p'
   mode     flags                    memsz    got.plt    dynamic tags
   none     &lt;none&gt;                   0x000208 present    none
   partial  -Wl,-z,relro             0x000208 present    none
   full     -Wl,-z,relro,-z,now      0x000230 ABSENT     BIND_NOW,FLAGS_1),

   the arithmetic that matters:
   none     RELRO 0x403df8..0x404000  ends on a page: YES
            .got.plt 0x403fe8..0x404008  CROSSES the RELRO end: YES  -&gt; 8 bytes stay writable
   full     RELRO 0x403dd0..0x404000  ends on a page: YES
            .got.plt ABSENT -- absorbed into .got, which is inside RELRO
</pre>
                </div>
                <p>Three rows, and the first one is the surprise: <strong><code>-z relro</code> changes nothing.</strong> Same size, same range, same everything. So on this toolchain there are not three states, there are two &mdash; and the flag people reach for is a no-op.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>What RELRO is, in one paragraph, and why it is a range:</p>
                <div class="formula">
  the GOT is a table of addresses the
  dynamic linker fills in. an attacker who
  can WRITE an entry controls where an
  indirect call goes.

  RELRO is the loader's answer: after it has
  finished filling the table, it tells the
  kernel "make this range read-only". the
  kernel does it with mprotect, and the
  program cannot write there afterwards.

  and the whole difficulty is the word
  "after". the loader must be able to write
  the GOT while it works. so the range can
  only be sealed once the loader is done.

  partial   seal everything EXCEPT the slots
            the loader might still write

  full     resolve everything FIRST, so the
            loader is done sooner and there is
            nothing left to write
                </div>
                <p>That is the entire design, and it explains why the two tiers are not a &ldquo;more versus less&rdquo; choice. <strong>Partial RELRO is not a weaker version of full; it is the same mechanism with a different answer to &ldquo;when does the loader stop writing&rdquo;.</strong> Under lazy binding the answer is &ldquo;whenever that function is first called&rdquo;, which is unpredictable and possibly never. So partial has to leave those pages writable.</p>
                <p>And the second half of the model is the part that surprises people, which is that <strong>RELRO is measured in pages, not bytes.</strong></p>
                <div class="formula">
  the loader hands the kernel a RANGE.
  the kernel rounds it OUT TO A PAGE and
  makes the whole page read-only.

  so the sealed region always ENDS on a
  page boundary. measured: all three builds
  end at 0x404000.

  which means -z now does not extend the
  range FORWARD. it extends it BACKWARD,
  so that the range's fixed forward end
  now covers strictly more.

      partial  0x403df8..0x404000
      full     0x403dd0..0x404000
                 ^^^^^^ 28 bytes earlier
                        ^^^^^^ same end
                </div>
            </div>

            <div class="unit unit-reality">
                <h2>The Eight Bytes</h2>
                <p>Now the arithmetic, which is the whole concept. Under partial RELRO on this build:</p>
                <div class="hex-dump">
                    <pre>    RELRO   0x403df8 .. 0x404000      (sealed, read-only)
              |---- 0x404000 ----|
    .got.plt 0x403fe8 .. 0x404008  |
              |  0x3fe8        |   |<- read-only: 24 bytes
              |---- 0x4000 ----|----|
                                |<- WRITABLE: 8 bytes
</pre>
                </div>
                <p><strong>Read it as three overlapping statements.</strong> The RELRO range ends at <code>0x404000</code>. The <code>.got.plt</code> section ends at <code>0x404008</code>. The difference is eight bytes, and those eight bytes are writable at run time while everything before them is not.</p>
                <p>Now the question that makes this a concept rather than a curiosity: <strong>what are those eight bytes?</strong> They are the tail of the lazy-binding table &mdash; the last PLT stub&rsquo;s slot, plus padding. And the loader writes to that table every time a function is resolved for the first time. So:</p>
                <div class="formula">
  PARTIAL RELRO
    the loader MAY write to the GOT, later,
    at a moment the program does not control.
    so the page must stay writable.
    -> an attacker with ANY write primitive
       can overwrite a GOT entry and redirect
       an indirect call, for the life of the
       process.

  FULL RELRO
    the loader resolves everything BEFORE
    main() runs. by the time the program has
    a single instruction, every GOT slot has
    its final value and will never change.
    so the page can be sealed.
    -> the same write primitive now hits a
       read-only page and SIGSEGVs.
                </div>
                <p><strong>So <code>-z now</code> is not an extra hardening measure bolted on after RELRO. It is the thing that makes RELRO complete.</strong> <a href="/courses/dyn/lessons/dyn-bind-time">The dynamic linking course</a> called <code>-z now</code> a change of timing with no code difference, and that is true and incomplete. This is the missing half: the timing change is what creates the <em>opportunity</em> to seal, and the section disappearing is the visible consequence of the sealing being possible.</p>
                <p>And the file agrees, in two independent ways. Under <code>-z now</code> the dynamic array grows tags &mdash; <code>DF_BIND_NOW</code> in <code>DT_FLAGS</code>, the <code>NOW</code> bit in <code>DT_FLAGS_1</code> &mdash; and the <code>.got.plt</code> section vanishes, because a table with one state does not need its own section. <strong>The tag is the loader&rsquo;s instruction to resolve early; the missing section is the proof that it did.</strong></p>
                <div class="hex-dump">
                    <pre>$ python3 harden.py relro_partial 2&gt;/dev/null | sed -n '6,11p'
  RELRO region                       0x403df8..0x404000
  RELRO tier                         partial
    .got.plt section                 present
    covered by RELRO                 NO
    ends on a page                   yes

$ python3 harden.py relro_full 2&gt;/dev/null | sed -n '6,11p'
  RELRO region                       0x403dd0..0x404000
  RELRO tier                         full
    .got.plt section                 absent
    covered by RELRO                 yes
    ends on a page                   yes
</pre>
                </div>
                <p>Note that <code>covered by RELRO</code> is the check that matters and it is the one that is easy to get wrong. <strong>The tier is what the dynamic array claims; the coverage is what the segment table proves.</strong> A reader that only checks the tags is trusting a promise. A reader that computes whether the GOT section actually fits inside the RELRO range is checking. The artifact does both and the concept treats the second as the real one &mdash; and that habit, checking the geometry rather than the flag, is the transferable part.</p>
            </div>

            <div class="unit unit-example">
                <h2>The Check Worth Writing</h2>
                <p>Since the tier is a promise and the coverage is the fact, the coverage check is the one to build. It is four lines and it needs the section table and the segment table, which is the whole point of having read both in earlier courses:</p>
                <div class="formula">
  got = section('.got.plt') or section('.got')
  lo, hi = relro.vaddr, relro.vaddr + relro.memsz

  covered = got.addr &gt;= lo and got.addr + got.size &lt;= hi

  # and one more that costs nothing:
  page_aligned = (hi % 0x1000) == 0
                </div>
                <p>The second check is nearly free and it is a genuine invariant, not a coincidence: <strong>the sealed range must end on a page boundary, because that is how the kernel applies it.</strong> If a future toolchain produced a RELRO range that did not end on a page, that would mean the sealing had changed shape, and it is worth an assertion that fires rather than a surprise discovered later.</p>
                <p>Now the honest complication, because it is a good one. <strong>The <code>.got.plt</code> section is absent under <code>-z now</code>, so a reader that looks only for <code>.got.plt</code> concludes &ldquo;no GOT, nothing to protect&rdquo;.</strong> The section was not eliminated; it was absorbed into <code>.got</code>. So the reader has to fall back:</p>
                <div class="formula">
  got = section('.got.plt') or section('.got')
      ^^^^^^^^^^^^^^^^
      if this is None, the answer is not
      "no GOT". it is "the lazy table is
      gone", which is the GOOD case, and you
      have to check .got to know that .got
      is inside the sealed range.
                </div>
                <p>That is a small thing that generalises to every parser in this collection: <strong>a missing thing is ambiguous.</strong> Absent <code>.got.plt</code> could mean full RELRO, or a static binary, or a file that is not what you think it is. Disambiguating it costs one more lookup, and skipping the lookup produces a report that says &ldquo;nothing to protect&rdquo; about the best-hardened binary in the set.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Try It Yourself</h2>
                <div class="hex-dump">
                    <pre>$ cd courses/sec/assets/samples
$ ./build_samples.sh 2&gt;&amp;1 | sed -n '/H3/,/H4/p'
$ python3 harden.py relro_none relro_partial relro_full
$ python3 crosscheck.py 2&gt;&amp;1 | sed -n '/H3/,/H4/p'
</pre>
                </div>
                <p>Then push on the claim, especially the part that is a flag with no effect:</p>
                <div class="hex-dump">
                    <pre>  1. Compare -z relro against NO flag, byte for
     byte, not size for size:
       cmp relro_none relro_partial
     (The earlier version of this course compared
     SIZES, found them equal at 0x208, and
     concluded -z relro does nothing. Comparing
     the files is the stronger claim and it
     should hold -- but CHECK it, because a
     size match does not prove a byte match.)

  2. Vary the environment size. Build the
     partial binary with a tiny environment and
     with a 200-entry one, and re-read the RELRO
     range both times. Does the writable tail
     grow? (It should not -- the tail is a
     function of the PLT stub count, not the
     environment. Confirming a non-dependence is
     as useful as finding a dependence.)

  3. Add a shared library that exports 300
     symbols, link it, and re-measure the
     writable tail. (This is where the argument
     gets sharp: under lazy binding each export
     has a slot, so the .got.plt grows, so the
     writable region grows. Plot tail size
     against export count. Now do the same
     with -z now. Under -z now the tail is
     ZERO at every export count, because there
     is no .got.plt to have a tail of. That is
     the whole argument for -z now as a
     SECURITY measure rather than a startup
     optimisation.)

  4. Take a real system binary and run
     harden.py on it. Then find the writable
     tail with the same arithmetic and confirm
     it with readelf. Does the distribution's
     hardening documentation agree with what
     the file says?

  5. Break the invariant. Hand-write a linker
     script that emits a PT_GNU_RELRO with a
     memsz that is NOT page-aligned, link with
     it, and run the artifact. (The page-aligned
     check fires, and it fires because the
     kernel rounds -- so you learn what the
     rounding hides: a range that LOOKS like it
     covers the GOT in the file may not cover
     it at run time. This is the same gap between
     the file and the running process that the
     img course found with AT_ENTRY.)
</pre>
                </div>
                <p>Exercise 3 is the one that makes the security argument quantitatively, and it is worth doing because it turns &ldquo;full RELRO is better&rdquo; into a number. <strong>The writable tail scales with the number of exported symbols, and <code>-z now</code> makes it zero at every size.</strong> That is a scaling argument rather than an aesthetic one: the exposure under partial RELRO grows with the size of your dependency tree, and the mitigation is a flag. It also explains why &ldquo;we already have RELRO&rdquo; is not an answer to a security review &mdash; it may be partial, and you cannot tell from the feature name.</p>
                <p>Exercise 5 is the deepest, and it is the same lesson the <a href="/courses/img/lessons/img-entries">image course</a> taught at a different layer. <strong>Everything you verify by reading the file is a statement about the file, and the kernel acts on a rounded version of it.</strong> The auxv said <code>AT_ENTRY</code> and the mapping agreed; here the segment says a range and the kernel applies a page-rounded range. A parser that reports what the file says is not lying, but it may not be describing what is true, and knowing which one you are reporting is the difference between a tool and a guess.</p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>This concept completes a debt owed by three earlier courses, and it is worth naming all three. <a href="/courses/sym/lessons/sym-plt">The symbol resolution course</a> built the PLT: one stub per imported function, one GOT slot each. <a href="/courses/dyn/lessons/dyn-bind-time">The dynamic linking course</a> measured that <code>-z now</code> changes no instructions and deletes <code>.got.plt</code>. <a href="/courses/link/lessons/link-phdrs">The linker script course</a> found where <code>.got.plt</code> is placed and why it needs its own output section rule. <strong>None of them could say why the section is <em>allowed</em> to be writable, and the answer is that it is the loader&rsquo;s scratch space until lazy binding is done.</strong> Each course had a correct local account; this is the one that makes them a single mechanism.</p>
                <p>The connection to <a href="/courses/img/lessons/img-place">Where the Kernel Put Everything</a> is the direct parent. That concept measured a process map and noted that a <code>GNU_RELRO</code> region appears as <code>r--p</code> because the loader asked for read-only after finishing its writes &mdash; and it said &ldquo;after&rdquo; without knowing why the timing was choosable. <strong>This is the why: the loader chooses when to ask, and <code>-z now</code> is how it chooses earlier.</strong> A flag in a link line becomes a <code>mprotect</code> call in the first milliseconds of a process&rsquo;s life, and the <code>r--p</code> in <code>/proc/&lt;pid&gt;/maps</code> is its result.</p>
                <p>Two connections that are about limits rather than mechanism. First, <a href="/courses/sec/lessons/sec-wx">the W<sup>^</sup>X concept</a> shows RELRO doing a second job: <code>.data.rel.ro</code> is the same sealing idea applied to a data section, and it is the reason <code>TEXTREL</code> is nearly extinct. <strong>RELRO is not one feature about the GOT; it is a general &ldquo;writable during load, sealed afterwards&rdquo; mechanism that happens to have been applied to the GOT first.</strong> Knowing that is what lets you predict the second use instead of being surprised by it. Second, <a href="/courses/sec/lessons/sec-posture">the posture concept</a> turns all of this into a check you run in CI, and the check it runs is this one &mdash; so this concept is the load-bearing row of that report.</p>
                <p>One connection to a course not yet written, which is worth flagging as a real limit. <strong>This is Linux and glibc.</strong> The mechanism is general &mdash; resolve before sealing, or do not seal &mdash; but the tag names, the section names and the <code>*_chk</code> symbol names are all platform conventions. The <a href="/courses/macho/lessons/macho-hardening">Mach-O hardening concept</a> in this collection gets the same guarantee a different way, and comparing the two is genuinely instructive: the mechanism is portable, the spelling is not.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/sec/lessons/sec-canary">Previous: The Canary and Its Limits</a></span>
                <span>Next: <a href="/courses/sec/lessons/sec-fortify">FORTIFY Leaves a Trace</a></span>
            </div>
        </div>


    render_lesson_js(&mut page)
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
