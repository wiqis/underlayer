// SIMD and Vector Processing — Concept 2: the compiler, the intrinsics, a control that lied
public namespace underlayer_content {

using std::string

using std::string_view

public func render_simd_compiler() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Compiler, the Intrinsics, and a Control That Lied — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson">
            <div class="a11y-controls">
                <button class="a11y-btn" onclick="toggleHighContrast()" aria-label="Toggle high contrast">HC</button>
                <button class="a11y-btn" onclick="toggleReducedMotion()" aria-label="Toggle reduced motion">RM</button>
                <button class="a11y-btn" onclick="openShortcuts()" aria-label="Keyboard shortcuts">?</button>
            </div>
            <div class="shortcuts-modal" id="shortcuts-modal">
                <div class="shortcuts-backdrop" onclick="closeShortcuts()"></div>
                <div class="shortcuts-dialog">
                    <h3>Keyboard Shortcuts</h3>
                    <dl>
                        <dt><kbd>Ctrl</kbd>+<kbd>K</kbd></dt><dd>Open search</dd>
                        <dt><kbd>Esc</kbd></dt><dd>Close search / dialog</dd>
                        <dt><kbd>&uarr;</kbd></dt><dd>Back to top</dd>
                    </dl>
                    <button onclick="closeShortcuts()" class="shortcuts-close">Close</button>
                </div>
            </div>
            <div class="reading-controls">
                <label>Font: <select id="font-size" onchange="setFontSize(this.value)"><option value="small">Small</option><option value="medium" selected>Medium</option><option value="large">Large</option></select></label>
                <label>Spacing: <select id="line-height" onchange="setLineHeight(this.value)"><option value="compact">Compact</option><option value="normal" selected>Normal</option><option value="relaxed">Relaxed</option></select></label>
                <label>Letters: <select id="letter-spacing" onchange="setLetterSpacing(this.value)"><option value="tight">Tight</option><option value="normal" selected>Normal</option><option value="loose">Loose</option></select></label>
                <label>Width: <select id="content-width" onchange="setContentWidth(this.value)"><option value="narrow">Narrow</option><option value="normal" selected>Normal</option><option value="wide">Wide</option></select></label>
            </div>
            <h1>The Compiler, the Intrinsics, and a Control That Lied</h1>
            <div class="lesson-meta">29 min &middot; <a href="/courses/simd">SIMD and Vector Processing</a></div>

            <div class="unit unit-why">
                <h2>Why this matters</h2>
                <p>Almost every conversation about SIMD is the same conversation, and it is always conducted in terms of intrinsics: intrinsics beat the compiler, or the compiler beats intrinsics, or the compiler would have done it if you had written it differently. <strong>That conversation cannot be settled with a stopwatch</strong>, and this concept is the one where this course says so and then does the thing that settles it.</p>
                <p>Start with the result, because it is the first thing a reader expects and it is a null:</p>
                <div class="hex-dump">
                <pre>$ ./simdbench | sed -n '/THE COMPARISON, as SPEEDUPS/,/AND THE FINDING/p'
   THE COMPARISON, as SPEEDUPS over the floor B (higher is faster):
      2 lanes (C) / 1 lane (B)                    2.00x
      4 lanes (D) / 1 lane (B)                    3.90x   &lt;- the lane count is 4
      4 lanes with FMA (E) / 4 lanes without (D)   1.00x   &lt;- FMA's contribution
      the hand-written 4-wide (E) / the compiler (A)   1.00x
      one fewer memory op (F) / three loads (E)     1.12x   &lt;- SLOWER, and that
         is the finding: a memory operand buys a shorter instruction and
         costs a longer dependency.  Instruction COUNT is not the cost.
  </pre>
                </div>
                <p>The auto-vectorised arm of a plain C loop and a hand-written 4-wide intrinsic loop over the same 64 doubles came out <strong>identical to two significant figures</strong>. A compiler will vectorise a straightforward loop at <code>-O2</code> these days, and it will do it about as well as you would. The interesting part is the last row, which is <em>slower</em>: the arm that removes a whole load by folding it into the FMA as a memory operand.</p>
                <p>And then the part that made this course retract two of its own claims. The same compiler, handed the <em>same statement</em> through a different declaration, produces a loop that is <strong>35&times; slower than the vectorised one and slower than the scalar floor</strong>:</p>
                <div class="hex-dump">
                <pre>   L1                         0 KiB        2 KiB     0.719      0.185         3.89x           3.90x              0.11x
   beyond L3               8192 KiB    24576 KiB     1.531      1.340         1.14x           1.18x              0.23x
       (last two columns: auto-vec through NAMED arrays, and through double *)
  </pre>
                </div>
                <p><strong>The difference between 3.90&times; and 0.11&times; is three <code>double *</code> declarations.</strong> Not the trip count, not the optimisation level, not a missing <code>-march</code>. That is a fact about code generation, and it is the reason this concept exists: <strong>you cannot find it with a stopwatch, because both arms are timings and the timings only tell you that one was fast.</strong></p>
            </div>

            <div class="unit unit-model">
                <h2>The model: four forms, two variables, one 2&times;2</h2>
                <p>To find out what the compiler actually does, you look at what the compiler actually emitted. The artifact compiles <strong>four forms of one statement</strong> with the same flags, crossing two independent variables:</p>
                <div class="formula">
   THE STATEMENT, four times:

     for (it...) for (j...)  A[j] = A[j] * B[j] + C[j];

   variable 1: is the trip count a COMPILE-TIME CONSTANT?
   variable 2: are A, B, C NAMED ARRAYS, or reached through
               three `double *` globals?

   named_const    constant trip count, named arrays
   named_var      runtime trip count,  named arrays
   ptr_const      constant trip count, pointers
   ptr_var        runtime trip count,  pointers
                </div>
                <p>And <code>build_samples.sh</code> appends the disassembly of all four to the recorded output, because <strong>a claim about what a compiler did is a claim about bytes</strong> and the only way to check one is to read them:</p>
                <div class="hex-dump">
                <pre>$ tail -30 simdbench.out
   named_const:
              1 vfmadd132pd
        =&gt; VECTORISED: 1 packed-double, 0 scalar
   named_var:
              1 vfmadd132pd
              1 vfmadd132sd
        =&gt; VECTORISED: 1 packed-double, 1 scalar
   ptr_const:
        =&gt; NOT VECTORISED: 0 packed-double, 1 scalar
   ptr_var:
        =&gt; NOT VECTORISED: 0 packed-double, 1 scalar
  </pre>
                </div>
                <p>Read it as a 2&times;2 and the result is unambiguous and it is not the one this course was written to say:</p>
                <div class="formula">
              trip count
              constant   runtime
 named    VECTOR    VECTOR
 arrays
 ptrs     SCALAR    SCALAR

   THE TRIP COUNT DECIDES ALMOST NOTHING.  The one thing it
   costs the named form is a SCALAR EPILOGUE for n mod 4 --
   that is the extra vfmadd132sd in named_var -- and
   section 6c of this artifact MEASURES that epilogue as
   free.

   THE POINTERS DECIDE EVERYTHING.  A loop that reads three
   streams and writes one cannot be reordered into a vector
   loop unless the compiler can prove a store to A[j] does
   not change what B[j+4] holds.  With three NAMED arrays
   that proof is immediate.  With three `double *` globals
   it is unavailable, and there is no vector loop.
                </div>
                <p>That is aliasing, and it is worth being precise about the word because &ldquo;aliasing&rdquo; is usually a claim that two pointers <em>are</em> equal. Here it means the compiler cannot prove they are <strong>not</strong>. One <code>restrict</code> qualifier, or three arrays instead of three pointers, is the entire difference between the two columns of that table.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The reality: the first draft of this concept was wrong twice</h2>
                <p>The first version of this course reached the three arrays through pointers, measured the auto-vectorised arm sitting on the scalar floor, and wrote this:</p>
                <div class="hex-dump">
                <pre>   R7. "The compiler declined to vectorise because the trip count is a
       runtime variable."  WRONG, AND IT WAS AN INFERENCE FROM A TIMING.
  </pre>
                </div>
                <p><strong>It was an inference from a timing, and the disassembly says something else entirely.</strong> The named form vectorises at <em>both</em> trip counts. What the trip count costs is an epilogue, and the epilogue is free; what the pointers cost is the entire vector loop, and that is catastrophic. Two different mechanisms, one of them harmless and one of them ruinous, told as a single tidy sentence because a tidy sentence is what a number going the right way produces.</p>
                <p>And the same sentence carried a second error, which is the one this course was really about. The first draft also claimed that the compiler beats intrinsics <strong>&ldquo;because it hoists the loop-invariant loads of B and C&rdquo;</strong>. The disassembly shows B and C loaded <em>inside</em> the inner loop on every one of the sixteen iterations. <strong>They are not hoisted.</strong> What the compiler does is put A into the FMA as a memory operand &mdash; which is arm F in the table above, and the artifact measured arm F and it is <em>slower</em>. So the story was wrong twice: the mechanism is not hoisting, and the mechanism it gets confused with is not free.</p>
                <div class="formula">
   R7, THE PART THAT IS ABOUT METHOD:

     AN INFERENCE FROM A TIMING IS NOT A MEASUREMENT OF A
     COMPILER.  A number going the right way is not evidence
     about bytes.

     Every other harness in this collection says "exact for
     structure, shapes for timing".  This one had to learn a
     THIRD clause:

     FOR A CLAIM ABOUT WHAT A COMPILER DID, THE ONLY
     EVIDENCE IS THE DISASSEMBLY.

     And the first draft of this course had none.
                </div>
                <p>Now the part that makes it a course rather than a bug report. <strong>The control arm lied first.</strong> The point of the pointer column is that it is a control: the same statement, the only difference being a declaration. So it was written as</p>
                <div class="hex-dump">
                <pre>  /* the first control, which was not a control */
  static double *gA = bA, *gB = bB, *gC = bC;
                </pre>
                </div>
                <p>&mdash; and that is the same three arrays wearing a pointer costume. gcc folded the static initialisers away, proved the three streams distinct again, vectorised the control, and the control came out at <strong>3.91&times;</strong>, indistinguishable from the arm it was supposed to contradict. The measurement was not wrong. The control was not a control.</p>
                <div class="formula">
   R8. "The control arm came out at 3.91x, so aliasing is not
       what stopped the compiler."  THE CONTROL WAS NOT A
       CONTROL.

       A CONTROL THAT CANNOT FAIL IS NOT A CONTROL.  And a
       check that passes on an artefact that was not built is
       worse than no check, because it is COUNTED.

       THE DISCIPLINE: before believing that a control
       confirms something, MAKE IT FAIL ON PURPOSE AND
       CONFIRM THAT IT DOES.
                </div>
                <p>The fix was to assign the pointers in <code>main()</code> and reach them through <code>noinline</code> accessors, so the compiler cannot see through them. The arm then emits one scalar FMA and no vector one, and lands where the disassembly says it should. <strong>And the harness now has a check for the retraction itself</strong>, so a future edit that restores the static initialisers turns one group red by name.</p>
                <p>One thing the control is <em>not</em>, and it is worth saying because the honest reading matters: it is not a clean 35&times; of pure vectorisation. The <code>noinline</code> accessors put <strong>three calls in the inner loop</strong>, so the gap between the two columns is larger than the aliasing effect alone. The defensible claim is &ldquo;catastrophically worse&rdquo;, not a factor.</p>
            </div>

            <div class="unit unit-example">
                <h2>Worked: what to do about it</h2>
                <p>Four things, in the order they are worth doing.</p>
                <div class="formula">
   1. DO NOT REACH ARRAYS THROUGH POINTERS IF YOU WANT
      THE VECTORISER.  This is the whole finding.  Write

         void f(size_t n, double *a, double *b, double *c) &#123;
             for (size_t j = 0; j < n; j++) a[j] = a[j]*b[j] + c[j];
         &#125;

      and you have asked for the scalar version, because a
      store to a[j] might change b[j+4] and the compiler
      cannot prove otherwise.  Adding `restrict` to all
      three parameters is the entire fix, and it is a
      PROMISE, so it is one you must be able to keep.

   2. OR WRITE THE INTRINSICS, which say what they mean and
      do not need the proof.  They lose nothing else: the
      table above has the hand-written 4-wide arm and the
      compiler's arm within a percent of each other.

   3. CHECK WITH -fopt-info-vec-missed, not with a timer.
      The compiler will tell you, by line, why it declined.
      A timer cannot, and this course's own first draft is
      the proof: a plausible ratio, an elaborate
      explanation, and a disassembly that said something
      else.

   4. REMEMBER -O2 IS NOT -O0.  Since GCC 12, -O2
      enables -ftree-vectorize under the "very-cheap" cost
      model.  The whole first column of this course's
      table exists because of that, and on GCC 11 or Clang
      of the same vintage the same -O2 would produce the
      scalar arm for the named form too.
                </div>
                <p>And the reason this is worth a whole concept rather than a footnote: the same reasoning applies to every &ldquo;the compiler did not do the obvious thing&rdquo; report you will ever be handed, in every language. <strong>The compiler's behaviour is a fact about a specific program, a specific version, and a specific set of flags, and a timing is not a way of establishing it.</strong> The disassembly is one command and it settles the question; the stopwatch starts a four-hour argument.</p>
                <p>There is one more reading of the table that is worth making, because it is the one that survives being wrong. The auto-vectorised arm and the hand-written arm are within a percent &mdash; but that is <em>on this loop</em>, on this machine, at this working-set size, and the previous concept measured the same two arms at five working-set sizes where the whole question stops mattering. <strong>A compiler that matches your intrinsics on an L1-resident loop is not telling you anything about an L3-resident one.</strong> Both facts are in the same artifact and they are about different ceilings.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Apply it</h2>
                <ol>
                    <li><strong>Do the manifest&rsquo;s exercise: make the control fail.</strong> In <code>simdbench.c</code>, change <code>static double *gA, *gB, *gC;</code> to <code>static double *gA = bA, *gB = bB, *gC = bC;</code> and delete the three assignments in <code>sec_ceiling</code>. Rebuild, run, rerun the harness. <em>(Expect the pointer column to come back to about 3.9&times; and group D to fail on the control checks by name. Write down which checks failed <em>before</em> you predict which would &mdash; the gap is usually a check you did not know existed. Then put the assignments back.)</em></li>
                    <li><strong>Run the four forms yourself and read the bytes, not the times.</strong> <code>./verify_codegen.sh /tmp/whatever.out</code> and then <code>objdump -d --no-show-raw-insn</code> the object it made. <em>(Expect the 2&times;2 above, and expect it to be exactly the same on your machine. If it is not, your compiler has a different cost model and the first thing to check is whether <code>-O2</code> still means <code>-ftree-vectorize</code> in your version. Note which of the four forms you would have got wrong by timing alone.)</em></li>
                    <li><strong>Add <code>restrict</code> to a real function of yours and disassemble it before and after.</strong> <em>(Expect the scalar version to become a 4-wide <code>vfmadd</code> loop with a scalar epilogue, and expect the change to be one keyword. Then check the call sites: <code>restrict</code> is a promise that the three pointers do not overlap, and the compiler will not verify it. An overlapping call is undefined behaviour you wrote yourself.)</em></li>
                    <li><strong>Use <code>-fopt-info-vec-missed</code> on a loop you expected to be vectorised.</strong> <em>(Expect a per-line reason, and expect the reason to be a cost-model judgement or an aliasing one rather than &ldquo;could not vectorise&rdquo;. This is the direct replacement for the stopwatch argument: it takes ten seconds and it is right.)</em></li>
                    <li><strong>Find a case where the intrinsics win anyway.</strong> Restrict two of the three pointers, or use a <code>#pragma GCC unroll</code>, or force the alignment. <em>(Expect a small number of cases and expect them to be about the epilogue or the alignment, never about the arithmetic. If you find one where the compiler emits a <em>worse</em> algorithm than you wrote &mdash; a different reduction order, a lost fusion &mdash; that is the interesting one, and it is worth writing down with the <code>-fopt-info</code> output beside it.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Backwards, <a href="/courses/simd/lessons/simd-width">the width concept</a> is the one whose table made this question necessary. It deliberately refused to say how much a wide instruction is worth &mdash; and this concept answers it in two halves: on an L1-resident loop the answer is &ldquo;the full width&rdquo; and the compiler gets it for free, and on anything else the answer is &ldquo;almost nothing&rdquo; and the compiler getting it for free is the point.</p>
                <p>Forward, <a href="/courses/simd/lessons/simd-shapes">the shapes concept</a> answers the question this one raises and does not: if the compiler's arithmetic and yours are identical and the loop is not waiting for the arithmetic anyway, what <em>is</em> a vector loop waiting for? The answer it measures is the load and the store, and the independence of the lanes, and those two facts are the last word on why the collapse in the previous concept happens where it does.</p>
                <p>Outward, the connection to a code generator is direct and it is the point of the course so far. <a href="/courses/isa/lessons/isa-length">The ISA course's length concept</a> is where the encodings are, and this concept is the place where you find out which one the compiler picked and why. <a href="/courses/priv/lessons/priv-harness">The privilege course's harness</a> is the model for what the group D checks do, and it has the same three rules plus four documented failures of its own; reading it next to this one is how you learn that <em>a check written to defend a claim rather than a measurement is a check that launders the claim</em> &mdash; which is precisely the error R7 and R8 are. And <a href="/courses/smp/lessons/smp-harness">the multiprocessor harness</a> is the immediately preceding instance, whose first check asserted a difference its own data contradicted.</p>
                <p>One outward-facing consequence, and it is the most useful thing in the concept. <strong>On a machine where the compiler declines to vectorise, the difference between a fast loop and a slow one is frequently a type declaration.</strong> That is a sentence about code generation that holds in every language in this collection's orbit, and it is worth carrying into <a href="/courses/wasm/lessons/wasm-instructions">the WebAssembly course's instruction concept</a>, where the same aliasing question decides whether a <code>simd</code> type is worth using at all.</p>
            </div>

            <div class="lesson-footer">
                <span>Previous: <a href="/courses/simd/lessons/simd-width">A Register With Lanes In It</a></span>
                <span>Next: <a href="/courses/simd/lessons/simd-shapes">Elementwise, and Independent</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
