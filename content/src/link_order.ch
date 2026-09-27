// Static Linking and Linker Scripts — Module 1: The Script You Already Use
// Concept: first-match-wins, proven in four cells, plus the hot/cold partition
// that rule order exists to serve.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_link_order() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Which Rule Wins — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson link-lesson">
            <a href="/courses/link" class="back-link">Back to course</a>
            <h1>Which Rule Wins</h1>
            <div class="lesson-meta">21 min &middot; Module 1: The Script You Already Use &middot; Intermediate</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Here is a rule with several patterns in it, taken from the 276-line default script:</p>
                <div class="hex-dump">
                    <pre>  .text :
  {
    *(.text.unlikely .text.*_unlikely .text.unlikely.*)
    *(.text.exit .text.exit.*)
    *(.text.startup .text.startup.*)
    *(.text.hot .text.hot.*)
    *(SORT(.text.sorted.*))
    *(.text .stub .text.* .gnu.linkonce.t.*)
  }
</pre>
                </div>
                <p>Six rules, and a program with ten functions has its <code>.text</code> divided among them. <strong>The question this concept answers is: what decides which function lands where?</strong> Not the compiler. The compiler chose the <em>names</em>; the script decides the order.</p>
                <p>Here is the proof, and it needs a two-function program compiled so that the compiler's own choice is visible:</p>
                <div class="hex-dump">
                    <pre>$ cat hot.c &lt;&lt;'EOF'
#include &lt;stdio.h&gt;
int cold(int x){ if (x % 7 == 3) return x * 13; return x + 1; }
int hot(int x){ return x * 3 + 1; }
int main(void){ long s = 0; for (int i = 0; i &lt; 100000; i++) s += hot(i);
                 printf("%ld %d\n", s, cold(9)); return 0; }
EOF
$ clang -O2 -ffunction-sections -fdata-sections -c hot.c -o hot.o
$ readelf -SW hot.o | sed -n 's/^ *\[[ 0-9]*\] \(\.text[^ ]*\).*/\1/p' | cat -n
  1     .text
  2     .text.cold
  3     .text.hot
  4     .text.main

$ clang -O2 -o hot hot.o
$ objdump -d hot --section=.text | sed -n 's/^[0-9a-f]* &lt;\(hot\|cold\|main\)&gt;:/&lt;\1&gt;/p'
&lt;hot&gt;
&lt;cold&gt;
&lt;main&gt;
</pre>
                </div>
                <p><strong>The object has them in the order cold, hot, main. The binary has them in the order hot, cold, main.</strong> Not the compiler's order, and not alphabetical. The script moved <code>hot</code> to the front because <code>.text.hot</code> is matched by rule four, and it left <code>cold</code> and <code>main</code> in object order because both fell into the same catch-all rule six.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Two orderings, and they are different orderings. Keeping them apart is the entire concept.</p>
                <div class="formula">
  ORDER 1  WHICH RULE (across output-section rules)
           the script's SECTIONS block, top to bottom.
           first rule that matches a section WINS. a
           section is assigned exactly once and never
           reconsidered.

  ORDER 2  WHERE IN THE OUTPUT (within one rule)
           the order of the PATTERNS inside the parens,
           and within one pattern, the order the
           sections appeared in the INPUT objects.

  so a section is placed by:
     which rule caught it   (ORDER 1)
     then which pattern     (ORDER 2, left to right)
     then object order      (ORDER 2, tiebreak)

  and .text.hot beats .text.* because rule four comes
  before rule six, and beats .text because .text.hot is
  listed before .text in the OUTPUT's own rule sequence.

                </div>
                <p><strong>And the tiebreak is object order, which is why <code>cold</code> precedes <code>main</code> rather than being sorted.</strong> The linker does not sort unless you write <code>SORT</code> or <code>SORT_BY_NAME</code>. It preserves what it was given, and what it was given is the order the compiler emitted sections in &mdash; which is roughly the order the compiler decided to lay functions out, which is roughly source order.</p>
                <p>So there are <em>three</em> orderings in play, not two, and the third is the one that surprises people. The compiler's section order is an input, the script's pattern order is a filter, and the output is the composition. Changing the script changes which of the three dominates.</p>
                <p>Now the four-cell question, which is the one worth being certain about, because a plausible-sounding answer is wrong:</p>
                <div class="formula">
  THE QUESTION
  a section matches rule A and also rule B. A is
  first. Does A win?

  THE COMPLICATION
  what if one of them is /DISCARD/? /DISCARD/ is a
  rule, it is just usually written last. does being
  written last give it special power?

  THE INTUITIVE ANSWER
  "/DISCARD/ is a safety net, it overrides"
  THIS IS WRONG. and the way I found out is the
  interesting part.

                </div>
            </div>

            <div class="unit unit-reality">
                <h2>Does It Actually Work?</h2>
                <p>Four cells, each a real link, each with the keep rule placed <em>first</em>:</p>
                <div class="hex-dump">
                    <pre>$ cat note2.c &lt;&lt;'EOF'
__asm__(".section .note.mytest,\"\",@progbits\n .long 0x12345678\n");
int main(void){ return 0; }
EOF
$ clang -O1 -c note2.c -o note2.o
$ python3 - &lt;&lt;'PY'
s = open('default.ld').read()
KEEP = '  .mynote : { *(.note.mytest) }\n'
DISC = '  /DISCARD/ : { *(.note.mytest) }\n'
open('cell_a.ld','w').write(s.replace('SECTIONS\n{', 'SECTIONS\n{'+KEEP, 1))
open('cell_b.ld','w').write(s.replace('SECTIONS\n{', 'SECTIONS\n{'+DISC, 1))
open('cell_c.ld','w').write(s.replace('SECTIONS\n{',
                          'SECTIONS\n{'+KEEP+DISC, 1))
open('cell_d.ld','w').write(s.replace('SECTIONS\n{',
                          'SECTIONS\n{'+DISC+KEEP, 1))
PY
$ for c in a b c d; do
    clang -O1 note2.o -o cell_$c -T cell_$c.ld
    printf "  %s  .mynote kept: %s\n" $c "$(readelf -SW cell_$c|grep -c mynote)"
  done
  a  .mynote kept: 1
  b  .mynote kept: 0
  c  .mynote kept: 1
  d  .mynote kept: 0
</pre>
                </div>
                <p><strong>One, zero, one, zero. Plain first-match-wins with no exception for anything.</strong> In cell C the keep rule is first and wins, so the <code>/DISCARD/</code> on the next line never gets a chance. In cell D the roles are reversed. <code>/DISCARD/</code> is not a safety net; it is the last rule in a script that happens to end with one.</p>
                <p><strong>And I got this wrong first, and the way I got it wrong is the part worth keeping.</strong> The original experiment concluded that <code>/DISCARD/</code> beats rule order. It does not. The experiment was broken: the script generator chained two <code>str.replace()</code> calls, and in the file that produced the wrong answer the first one had not applied &mdash; so the variant I was calling &ldquo;keep rule first, discard second&rdquo; contained <strong>no keep rule at all</strong>. It was simply the discard-only cell, which of course discards.</p>
                <div class="hex-dump">
                    <pre>  the failure mode, exactly:

    # returns the text UNCHANGED when the pattern is absent,
    # and reports nothing. a no-op edit is indistinguishable
    # from a linker that ignored you.

    s.replace('SECTIONS\n{', 'SECTIONS\n{'+KEEP, 1) \
     .replace('/DISCARD/ : {', '/DISCARD/ : {'+DISC, 1)
            ^ this one is fine

    s.replace('SECTIONS\n{', 'SECTIONS\n{'+KEEP, 1) \
     .replace('DISCRD/ : {', 'DISCRD/ : {'+DISC, 1)
            ^ and THIS one silently did nothing, because
              /DISCARD/ is not DISCRD/ . the cell that
              "proved" /DISCARD/ wins had no /DISCARD/ in
              it, and no keep rule either.

  the fix is boring and should be automatic:

    before = s
    s = s.replace(needle, repl, 1)
    assert s != before, 'the edit did not apply'

  which is now in the build script, and crosscheck.py
  asserts each cell's script really contains the rule
  it is supposed to. the current crosscheck passes 116
  claims; two of them exist because of this.
</pre>
                </div>
                <p>There is a general lesson here that is worth more than the ordering rule itself, and it applies to every experiment in this course. <strong>When a build-tool experiment produces a surprising result, the first hypothesis should be that your edit did not apply &mdash; not that the tool is clever.</strong> A surprising result is much cheaper to explain as a mistake in the harness than as a discovery, and the mistake is invisible precisely because the tool did nothing.</p>
                <p>Now the thing that the ordering rule is <em>for</em>. Why does the default script spend six rules on <code>.text</code> when it could spend one?</p>
                <div class="hex-dump">
                    <pre>  rule 1  .text.unlikely  -- never taken, rarely used
  rule 2  .text.exit       -- the atexit path, cold
  rule 3  .text.startup    -- run once at startup
  rule 4  .text.hot        -- MEASURED HOT, runs constantly
  rule 5  .text.sorted     -- a name for "I sorted these"
  rule 6  .text .stub .text.*  -- everything else

  the intent: group the cold code together, the hot
  code together, and the startup code together. a CPU
  fetching instructions benefits from a working set
  that is CONTIGUOUS. this is the same reasoning as
  the hot/cold page splitting in the .data case, and
  it is a layout decision that no compiler can make on
  its own -- the compiler knows which function is hot,
  but only the linker knows all of them at once.
</pre>
                </div>
                <p><strong>That division of labour is the point, and it is the same shape as the <a href="/courses/sym/lessons/sym-algorithm">resolution algorithm</a>'s.</strong> The compiler makes a local decision per function (&ldquo;this one is cold, so name it <code>.text.cold</code>&rdquo;); the linker makes a global one (&ldquo;all the cold ones go here&rdquo;). Neither can do the other&rsquo;s job, and the naming convention <em>is</em> the interface between them &mdash; which is why the script has to hard-code <code>.text.hot</code> as a literal string, with no wildcard, to make the compiler&rsquo;s decision mean anything.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Ordering has consequences you can observe, and the one below is the classic embedded bug. Take the eleven-line script and give <code>.text</code> an explicit address:</p>
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
                <p><strong>The section is at 0x900000 and <code>answer</code> is at 0x9000f0.</strong> Setting the address of an output section sets the address of its <em>first byte</em>, and the first byte belongs to whatever the <em>first matching rule</em> put there &mdash; here <code>_start</code> and the C runtime, not your function. If a script needs &ldquo;my interrupt vector table at 0x80000000&rdquo;, the rule order has to put that section first, or the address is wrong by however much the runtime code occupies.</p>
                <p>And the fix is a one-line reorder, with a failure mode that is completely silent:</p>
                <div class="hex-dump">
                    <pre>  .text 0x80000000 : { *(.vectors) *(.text .text.*) }
                                      ^^^^^^^^^^ this must be FIRST

  put it second and the program still builds, still
  links, still runs, and the vector table is at
  0x80000000 + (size of everything the .text rule
  matched first). on hardware that checks, that is a
  hard fault. on a simulator, it may be fine. this is
  the shape of bug that a linker script introduces and
  a test suite does not catch.
</pre>
                </div>
                <p>The second consequence is <code>SORT</code>, and it is the one that makes the <code>.init_array</code> rules work. Constructors are ordered by a priority number that lives in the <em>section name</em>, and the script has to sort on it:</p>
                <div class="hex-dump">
                    <pre>  KEEP (*(SORT_BY_INIT_PRIORITY(.init_array.*) SORT_BY_INIT_PRIORITY(.ctors.*)))

  the names look like .init_array.00705 and
  .init_array.65535. SORT_BY_INIT_PRIORITY reads the
  NUMBER out of the name and orders by it. without the
  sort operator, they would run in object order, which
  is whatever order the linker happened to receive the
  objects in -- and a priority-105 constructor that runs
  after a priority-65535 one is a bug that manifests as
  uninitialised global state at random.

  and .init uses SORT_NONE explicitly:
      KEEP (*(SORT_NONE(.init)))
  which is the same idea inverted: this one must NOT be
  sorted, and the script says so.
</pre>
                </div>
                <p><strong>A number encoded in a section name, read back out by a linker script, is one of the more baroque mechanisms in the toolchain and it is load-bearing.</strong> It is also a good illustration of why scripts have more operators than they appear to: each one is a real requirement discovered by somebody whose program broke without it.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Try It Yourself</h2>
                <div class="hex-dump">
                    <pre>$ cd courses/link/assets/samples
$ ./build_samples.sh 2&gt;&amp;2 | sed -n '/F4/,/F6/p'
$ python3 crosscheck.py 2&gt;&amp;2 | sed -n '/\\[4\\]/,/\\[6\\]/p'
$ python3 linklab.py order
</pre>
                </div>
                <p>Then break ordering on purpose and watch what does and does not move:</p>
                <div class="hex-dump">
                    <pre>  1. In hot.o, .text.cold and .text.main both match
     rule 6. Swap the order of .text.unlikely and
     .text.hot in the script. Does `hot` still come
     first? (It should -- both still precede rule 6.)

  2. Move the catch-all rule 6 to be rule 1. Now what
     order? (Everything falls into it first, so the
     answer is object order: cold, hot, main. The hot/cold
     partition is GONE and nothing warns you.)

  3. Add a second rule for .text.hot at the END of the
     .text block, writing to a DIFFERENT output section
     named .text.hot. Which one gets the content?

  4. Use SORT_BY_NAME on rule 6 and re-run. Now the
     order is alphabetical. Which of your three functions
     moves, and does the program still work?

  5. Put /DISCARD/ FIRST in the default script and relink
     the hello world. It still works. Now add
     *(.text) to the /DISCARD/ and relink. What error,
     and does the error name the section?
</pre>
                </div>
                <p>Exercise 2 is the one that matters, and its result is the lesson. <strong>Deleting the hot/cold partition does not break anything.</strong> There is no diagnostic, the binary is a different size, the program returns the right answer, and the only thing you have lost is a performance property that nobody can measure without a profiler and a long run. <strong>That is the shape of most linker-script decisions: they are optimisations, and the linker never tells you when you have removed one.</strong> The exceptions are the ones where correctness depends on order &mdash; a vector table, a <code>SORT_BY_INIT_PRIORITY</code> list, an <code>EXCLUDE_FILE</code> that puts <code>crtend.o</code>&rsquo;s terminator last &mdash; and the way to tell them apart is to ask what breaks if the order is wrong, not what the compiler says.</p>
                <p>Exercise 5 is the last piece of the <code>/DISCARD/</code> story, and it is a good demonstration of a different kind of error: a rule that matches <em>too much</em> does not get a subtle failure, it gets a <code>/DISCARD/</code> rule that swallows all of <code>.text</code>, and a link that produces a binary with no code in it.</p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>This closes the first module. <a href="/courses/link/lessons/link-default-script">The Program That Placed Your Binary</a> established that the script is source you can read; <a href="/courses/link/lessons/link-script-language">The Language</a> gave you the eight constructs; this one gave you the <em>evaluation order</em>, which is the part you cannot guess and the part that has consequences.</p>
                <p>The strongest connection is to the <a href="/courses/reloc/lessons/reloc-arch-contrast">AArch64 contrast</a> in the Relocations course, and it is a structural rhyme worth noticing. That concept found that AArch64 needs <em>two</em> relocations per reference because one instruction cannot reach far enough, and that a tool must therefore treat relocation entries as a set with an ordering constraint rather than individually. <strong>This concept is the same shape one layer up:</strong> a section matching several rules must be treated as a set with an ordering constraint, and a patcher that processes them independently produces a plausible file rather than an error.</p>
                <p>The second connection is about where the compiler's decisions stop. <strong>The <code>.text.hot</code> partition is a global decision made from local information.</strong> The compiler knows one function is hot; the linker knows all of them, and only the linker can act on it. That is the same division as the <a href="/courses/sym/lessons/sym-order">command-line ordering</a> question in the symbol course &mdash; whether an archive member gets pulled in depends on what every <em>other</em> member wanted &mdash; and it is worth holding as a general shape: <em>local facts, global consequences, a later pass that knows everything.</em> Scripts and linker scripts are both instances of it, and the pass that runs last is the one that decides.</p>
                <p>Forward into the placement module, this concept supplies the answer to the question the grammar deferred. <a href="/courses/link/lessons/link-location-counter">The Location Counter</a> is about <em>where</em> the output section starts, and this concept is about <em>what is in it and in what order</em>. Those two are independent, and the trap at the end of this page &mdash; <code>.text 0x900000</code> putting <code>answer</code> at <code>0x9000f0</code> &mdash; is exactly what happens when you conflate them. The address sets the first byte; rule order decides who owns it.</p>
                <p>And the connection into the selection module is the sharpest one here, because <code>KEEP</code> is one of the five operators introduced above and this is where it earns its keep. <a href="/courses/link/lessons/link-keep-gc">Reachability, and Who the Roots Are</a> shows that a constructor nobody calls survives garbage collection purely because the script says <code>KEEP (*(.init_array))</code>. <strong>A word inside parentheses, in a file the reader has never opened, is the only reason that code is still in the binary.</strong> Ordering decides where things go; <code>KEEP</code> decides whether they are there at all, and that is a bigger difference than it sounds.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/link/lessons/link-script-language">Previous: The Language, in the Order It Runs</a></span>
                <span>Next: <a href="/courses/link/lessons/link-location-counter">The Location Counter</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
