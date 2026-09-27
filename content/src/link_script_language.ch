// Static Linking and Linker Scripts — Module 1: The Script You Already Use
// Concept: the grammar, in the order the linker actually evaluates it.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_link_script_language() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Language, in the Order It Runs — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson link-lesson">
            <a href="/courses/link" class="back-link">Back to course</a>
            <h1>The Language, in the Order It Runs</h1>
            <div class="lesson-meta">24 min &middot; Module 1: The Script You Already Use &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>A linker script looks like C and is not C. That is the source of nearly every confusion a reader has with one, because C-trained eyes supply rules the language does not have &mdash; and the differences are all in the direction of <em>more</em> being true than you expect, not less.</p>
                <p>Here is a complete, working script. It is small, it links a real program, and it uses every construct that matters in the default one:</p>
                <div class="hex-dump">
                    <pre>OUTPUT_FORMAT("elf64-x86-64", "elf64-x86-64", "elf64-x86-64")
OUTPUT_ARCH(i386:x86-64)
ENTRY(_start)
SEARCH_DIR("=/lib/x86_64-linux-gnu")
SECTIONS
{
  . = 0x400000 + SIZEOF_HEADERS;
  .text  : { *(.text .stub .text.*) }
  . = ALIGN(0x1000);
  .rodata : { *(.rodata .rodata.*) }
  .data   : { *(.data .data.*) }
  .bss    : { *(.bss .bss.*) }
  /DISCARD/ : { *(.note.GNU-stack) }
}
</pre>
                </div>
                <p>Eleven lines, and every one of them is doing something. This concept is the tour.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Two phases, and almost every misunderstanding is a confusion about which phase a construct belongs to.</p>
                <div class="formula">
  PHASE 1  DECIDE THE OUTPUT'S IDENTITY
           OUTPUT_FORMAT  the three file formats
           OUTPUT_ARCH    the target
           ENTRY          the root symbol
           SEARCH_DIR     where archives are looked for

           these do not depend on the inputs. they are
           answered before a single object file is opened.

  PHASE 2  WALK SECTIONS, IN SCRIPT ORDER
           SECTIONS ...            the one block that is
                                    walked in order
  (braces are legal in a script and illegal in this
   box, so a brace-delimited list is written "..." here
   and quoted for real in the dumps below)

           for each output section, in the order written:
             which input sections go in it   (first match)
             where it starts                 (the counter)
             what it contains                (the rules)
             what it is called

  A CONSTRUCT IN THE WRONG PHASE IS NOT AN ERROR.
  it is ignored, or it is a syntax error, and both
  are silent-ish. which is worse.

                </div>
                <p><strong>Phase 1 is why you can put <code>ENTRY</code> before <code>SECTIONS</code> and nothing breaks</strong>, and why putting it inside <code>SECTIONS</code> is a syntax error rather than a surprise. The commands are not a sequence of statements to be executed in order; they are a set of settings, plus one block that is walked in order.</p>
                <p>Now the four things you can do inside <code>SECTIONS</code>, which is the entire inner language.</p>
                <div class="formula">
  1. MOVE THE COUNTER

       . = 0x400000;
       . = ALIGN(4096);
       . = . + 16;
       . = SEGMENT_START("text-segment", 0x400000);

     the dot is a variable. everything else in the
     language can be an expression over it.

  2. DECLARE AN OUTPUT SECTION

       .text 0x600000 : ...
       |     |       |    |
       |     |       |    +-- the rules: what goes inside
       |     |       +------- the colon
       |     +--------------- an explicit ADDRESS (optional)
       +--------------------- the output section's name

  3. WRITE A RULE

       *(.text .stub .text.*)
       ^ a wildcard over input section names

       *crtbegin.o(.ctors)
       ^ a FILE PATTERN, then a section inside that file

       KEEP (*(.init_array))
       ^ KEEP: a root for garbage collection

       PROVIDE (x = .);
       ^ define a symbol, only if something wants it

  4. DISCARD

       /DISCARD/ : *(.comment)

                </div>
                <p><strong>There is no <code>if</code>, no loop, and no variable other than the dot.</strong> That is the entire control-flow surface. A linker script is a straight line with a wildcard matcher, and if you are looking for the C in it, this is the list of things that is not there.</p>
            </div>

            <div class="unit unit-reality">
                <h2>Does It Actually Work?</h2>
                <p>Every construct above, exercised. Start from the eleven-line script and check each one actually did what it looks like it did.</p>
                <div class="hex-dump">
                    <pre>$ cat &gt; probe.ld &lt;&lt;'EOF'
OUTPUT_FORMAT("elf64-x86-64")
ENTRY(_start)
SECTIONS
{
  . = SEGMENT_START("text-segment", 0xDEADBEEF) + SIZEOF_HEADERS;
  .text  : { *(.text .stub .text.*) }
}
EOF
$ clang -O1 -fno-pie -no-pie hello.o -o probe.out -T probe.ld \
      -Wl,-u,SEGMENT_START 2&gt;/dev/null || true
</pre>
                </div>
                <p>That is not the right way to read a value out. <a href="/courses/link/lessons/link-default-script">The previous concept</a> established the technique &mdash; <code>PROVIDE</code> plus <code>-u</code> &mdash; and it is worth doing properly for the two functions that most people cannot predict, because both have names that promise more than they deliver.</p>
                <div class="hex-dump">
                    <pre>$ python3 - &lt;&lt;'PY'
s = open('default.ld').read()
s = s.replace('SECTIONS\n{', 'SECTIONS\n{\n'
  '  PROVIDE(__p_text = SEGMENT_START("text-segment", 0xDEADBEEF));\n'
  '  PROVIDE(__p_max  = CONSTANT(MAXPAGESIZE));\n'
  '  PROVIDE(__p_hdr  = SIZEOF_HEADERS);', 1)
open('probe.ld','w').write(s)
PY
$ clang -O1 -fno-pie -no-pie hello.o -o probe.out -T probe.ld \
      -Wl,-u,__p_text -Wl,-u,__p_max -Wl,-u,__p_hdr
$ readelf -sW probe.out | grep __p_
    7: 00000000deadbeef     0 OBJECT  LOCAL DEFAULT    1 __p_text
    8: 0000000000001000     0 OBJECT  LOCAL DEFAULT    2 __p_max
    9: 0000000000000350     0 OBJECT  LOCAL DEFAULT    3 __p_hdr
</pre>
                </div>
                <p><strong>Three results, and two of them correct the obvious reading of the name.</strong></p>
                <div class="hex-dump">
                    <pre>  SEGMENT_START("text-segment", 0xDEADBEEF)
      returned 0xdeadbeef -- the SECOND argument.

      you would bet the first is a query to the target
      emulation and the second is a fallback. on
      x86-64 Linux the emulation has no opinion about
      "text-segment", so the fallback IS the answer.
      the name is a hook for targets that really do
      have named segments. the <a href="/courses/link/lessons/link-location-counter">location counter</a>
      concept is entirely about this function.

  CONSTANT(MAXPAGESIZE)   returned 0x1000. CORRECT,
      and the control is the point: this one DID ask
      the emulation, and got a real answer. so the
      probe mechanism works. the two functions differ.

  SIZEOF_HEADERS          returned 0x350 -- the ELF
      header, the program headers, and the section
      headers. this is the gap between "where the image
      starts" and "where your first byte of code is".
</pre>
                </div>
                <p>That gap is the thing to take away. <strong>The address you write is where the <em>image</em> goes, not where your code goes</strong>, and the difference is 0x350 bytes on this build. The <code>. =</code> on line 2 of the eleven-line script is not decoration; it is the whole reason the first byte of <code>.text</code> is not at 0x400000.</p>
                <p>Now the operators, all from the real default script, each with what it is for:</p>
                <div class="hex-dump">
                    <pre>  *(.text .stub .text.* .gnu.linkonce.t.*)
      the workhorse. a WILDCARD over input section
      names, matched against every section of every
      object. .text.* is a suffix match. the order of
      the names inside the parens is the order they are
      laid out -- that is the <a href="/courses/link/lessons/link-order">next concept</a>.

  KEEP (*(SORT_NONE(.init)))
      KEEP makes the section a ROOT for --gc-sections.
      SORT_NONE means "leave the order alone". the
      .init rule needs it because the init code must
      come first.

  KEEP (*(SORT_BY_INIT_PRIORITY(.init_array.*) ...))
      a SORT operator. priority numbers live in the
      input section NAME (.init_array.65535), and this
      rule makes constructors run in priority order.
      SORT_NONE, SORT, SORT_BY_NAME, SORT_BY_INIT_PRIORITY
      and SORT_WITH_SIZE all exist.

  KEEP (*(.init_array EXCLUDE_FILE (*crtbegin.o ...)))
      EXCLUDE_FILE subtracts. the .ctors section of
      crtbegin.o must come FIRST and crtend.o's must
      come LAST, so both are excluded from the ordinary
      rule and placed by dedicated KEEP rules above it.

  *crtbegin.o(.ctors)
      a FILE PATTERN rather than a section wildcard.
      "the .ctors section of crtbegin.o, whichever
      directory it is in."

  *(.eh_frame) ONLY_IF_RO { ... }
      the ONE conditional in the language. the
      emulation substitutes ONLY_IF_RO or ONLY_IF_RW
      when it reads the script, which is why .eh_frame
      appears twice in the default script: once for a
      read-only segment, once for a read-write one,
      and exactly one of the two survives.
</pre>
                </div>
                <p><strong>That last one is the neatest thing in the file and almost nobody knows it is there.</strong> The script does not contain an <em>if</em> about whether a section is read-only. It contains the <em>same</em> section twice, guarded by a placeholder the target fills in. <a href="/courses/link/lessons/link-orphans">The orphan concept</a> returns to what happens to the rules that match nothing.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>The construct that separates a working script from a working <em>embedded</em> script: giving a section an explicit address.</p>
                <div class="hex-dump">
                    <pre>$ python3 - &lt;&lt;'PY'
s = open('default.ld').read()
s = s.replace('  .text           :\n', '  .text 0x900000 :\n', 1)
open('abs.ld','w').write(s)
PY
$ clang -O1 hello.o -o place_abs -T abs.ld
$ readelf -SW place_abs | awk '/ \.text /{print "  .text addr="$4}'
  .text addr=0000000000900000
$ readelf -sW place_abs | awk '/ answer$/{print "  answer =" $2}'
  answer =00000000009000f0
$ ./place_abs; echo "  ran, exit=$?"
  ran, exit=0
</pre>
                </div>
                <p><strong>One number changed, the section moved, and the program still worked.</strong> Note that <code>answer</code> is at <code>0x9000f0</code> and not <code>0x900000</code>: the input section for <code>answer</code> is not the first thing in <code>.text</code>, because <code>_start</code> and the C runtime's code come first. <strong>Setting the address of an output section sets the address of its first byte, not of your function.</strong></p>
                <p>That is worth a second measurement, because it is the single most common surprise when writing a real script: <em>which</em> input section ends up first is decided by the <em>rules</em>, and the rules are matched in order.</p>
                <div class="hex-dump">
                    <pre>  .text : { *(.text.cold) *(.text) *(.text.*) }

  vs

  .text : { *(.text) *(.text.*) *(.text.cold) }

  the first puts .text.cold at offset 0. the second
  puts .text at offset 0. same total size, different
  addresses for every function, and the program runs
  identically either way -- which is exactly why the
  mistake is silent.
</pre>
                </div>
                <p>And one more thing the language does that C-trained eyes get wrong, which is that a <strong>script is not required to name every section</strong>. Delete the <code>.rodata</code> rule from the eleven-line script and the link still succeeds, because the linker places what the script did not mention somewhere sensible of its own choosing. It will not tell you. That behaviour has a name and a flag, and it is the whole of <a href="/courses/link/lessons/link-orphans">the orphan concept</a> &mdash; and the measurement there finds <strong>five sections in a trivial hello-world that even the 276-line default script does not name</strong>, four of them from the C runtime.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Try It Yourself</h2>
                <div class="hex-dump">
                    <pre>$ cd courses/link/assets/samples
$ ./build_samples.sh 2&gt;&amp;1 | sed -n '/F1/,/F3/p'
$ python3 crosscheck.py 2&gt;&amp;1 | sed -n '/\\[1\\]/,/\\[3\\]/p'
$ python3 linklab.py base 0x3000000
</pre>
                </div>
                <p>Then write the eleven-line script yourself, from an empty file, in this order:</p>
                <div class="hex-dump">
                    <pre>  1. Start with NOTHING. Link with -T empty.ld and
     read the error. (It will complain about PHDRs
     before it complains about your sections. Note the
     order of the complaints -- that is the phase
     order from the model.)

  2. Add OUTPUT_FORMAT and ENTRY. Link again. What is
     the next complaint?

  3. Add a SECTIONS block with .text only. Link. Then
     run it. Then add .rodata, .data, .bss one at a
     time, running after each. Which one, if any, is
     REQUIRED for the program to run?

  4. Replace the literal 0x400000 with
     SEGMENT_START("text-segment", 0x400000). Does the
     binary change? (It should be identical, because on
     this target the function returns its second
     argument -- F2. Verify with cmp, not with size.)

  5. Now add ONLY_IF_RO to your .eh_frame rule and
     link. Does it work? What did the emulation
     substitute? (Use ld -v if you want to see it.)
</pre>
                </div>
                <p>Step 1 is the one that teaches the most, and it is the exercise I would put first in any linker course. <strong>Starting from a genuinely empty script and letting the linker tell you what it needs is how you learn what is required versus what is conventional.</strong> The answer, when you get there, is that almost nothing in the eleven-line script is required &mdash; <code>ENTRY</code> has a default, <code>OUTPUT_FORMAT</code> has a default, and sections you do not name get placed anyway. What the script is <em>for</em> is being a deliberate statement of layout rather than an accident of defaults, and knowing which parts are load-bearing is what tells you which parts you may safely omit.</p>
                <p>Step 4 is the trap this course has already hit twice. <code>cmp</code>, not <code>stat</code>. The <a href="/courses/link/lessons/link-default-script">round trip</a> and the <a href="/courses/link/lessons/link-order">four-cell ordering experiment</a> both produced a right-sized but wrong file at some point during writing, and both were caught only by comparing bytes.</p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>This concept supplies the grammar, and its only job is to make the next one possible. <a href="/courses/link/lessons/link-default-script">The Program That Placed Your Binary</a> gave you the file; this one gives you the eight constructs it is written in. <strong>Those three concepts together are a complete reading ability</strong> &mdash; enough for any linker script in the wild, which is the practical test.</p>
                <p>Forward within the module, the grammar immediately raises the question the previous concept deferred. The <code>.text</code> rule is <code>*(.text .stub .text.* .gnu.linkonce.t.*)</code> and the <code>.init_array</code> rule is <code>KEEP (*(SORT_BY_INIT_PRIORITY(.init_array.*) ...))</code>, and both contain <em>several</em> patterns. Which input section does a section matching two of them get? <a href="/courses/link/lessons/link-order">Which Rule Wins</a> answers that with a four-cell experiment, and the answer is that the order inside the parentheses is itself a decision with consequences &mdash; it is how the hot/cold partition works.</p>
                <p>Two connections backwards, both about a distinction the grammar forces you to notice. <strong>First: the dot is a variable and <code>SIZEOF_HEADERS</code> is a function, which is a different kind of thing from an <code>OBJECT</code> in the symbol table.</strong> The <a href="/courses/obj/lessons/obj-the-hole">Object Files course</a> called the zero displacement in an object file &ldquo;the hole&rdquo; and showed the linker filling it. This concept is where the hole is <em>measured</em>: the counter has a concrete value, <code>0x350</code> bytes past the image base, and the distance between &ldquo;where the image is&rdquo; and &ldquo;where your code is&rdquo; is a real, queryable number rather than a gap in understanding.</p>
                <p><strong>Second: <code>PROVIDE</code> is a script construct, and the <a href="/courses/sym/lessons/sym-linker-defined">linker-defined symbols</a> concept treated those symbols as a linker feature without asking where they were made.</strong> They are made here, by a line of script, and the difference between <code>PROVIDE</code> and a bare assignment is the difference between a symbol that exists in your binary and one that does not. If you have ever wondered why <code>__start_SEC</code> is missing from a particular binary, that is the answer, and it is one word in a grammar rather than a linker mystery.</p>
                <p>And the connection into the placement module is the sharpest one in the course. <code>. = SEGMENT_START(...) + SIZEOF_HEADERS</code> on line 2 of the default script is a <strong>statement about the relationship between the image base and the first byte of code</strong>, and the two summands are not interchangeable. <a href="/courses/link/lessons/link-location-counter">The Location Counter</a> is entirely about that statement: what the dot holds, when it moves, and why the address you typed and the address you got are 0x350 bytes apart. The grammar says the dot exists; that concept says what it is for.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/link/lessons/link-default-script">Previous: The Program That Placed Your Binary</a></span>
                <span>Next: <a href="/courses/link/lessons/link-order">Which Rule Wins</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
