// DWARF Course — Module 5: The Format on Other Inputs
// Concept: call-site information — the part of DWARF that describes a call that
// has already returned, verified field by field against the machine code.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_dwarf_call_sites() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Call Sites — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson dwarf-lesson">
            <a href="/courses/dwarf" class="back-link">Back to course</a>
            <h1>Call Sites</h1>
            <div class="lesson-meta">22 min &middot; Module 5: The Format on Other Inputs &middot; Algorithms</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Everything so far in this course describes <em>state</em>: a variable is in a register, a type is at this offset, code occupies these ranges. Call-site information describes something else &mdash; <strong>an event that already happened.</strong> The program called a function, that function returned, and now you are looking at a stack frame that no longer exists on the machine. The registers that held the arguments are gone. The only reason a debugger can still tell you what was passed is that the compiler recorded it at the moment of the call.</p>
                <p>That matters for a specific and very common situation: a crash report or a core dump. You have a return address, and you want to know which call it came from and what it was called with. Without call-site information the honest answer is "I can tell you the address, and the source line, and nothing about the arguments, because they are gone." With it, the answer is a register number and an expression, evaluated against the register state <em>as it was before the call</em>.</p>
                <p>And there is a second reason, which is the one that makes this concept worth decoding carefully. The optimiser rewrites calls. It inlines them, it tail-calls them, it merges two identical calls into one, and it turns a call with a computed argument into something the machine can do more cheaply. <strong>Call-site information is the record of what the optimiser did</strong>, and reading it is the closest thing DWARF comes to a disassembly with comments.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>A <code>DW_TAG_call_site</code> DIE is a child of a <code>DW_TAG_subprogram</code>, and there is one per distinct call in that function. Five things to know about it:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Attribute</th><th scope="col">Means</th></tr>
                    </thead>
                    <tbody>
                        <tr><td><code>DW_AT_call_return_pc</code></td><td>The address the call would return to. For a tail call, an address that is never actually reached</td></tr>
                        <tr><td><code>DW_AT_call_origin</code></td><td>The DIE of the thing being called &mdash; usually a subprogram <em>declaration</em></td></tr>
                        <tr><td><code>DW_AT_call_tail_call</code></td><td>Present and 1 when the call was compiled to a jump rather than a call</td></tr>
                        <tr><td><code>DW_AT_call_all_calls</code> (on the subprogram)</td><td>The fallback: if no call site matches, blame this function for everything</td></tr>
                        <tr><td><code>DW_AT_call_all_tail_calls</code> (on the subprogram)</td><td>The same, for calls that were tail calls</td></tr>
                    </tbody>
                </table>
                <p>And each call site has <code>DW_TAG_call_site_parameter</code> children, one per argument, with two attributes that are a pair and must be read together:</p>
                <div class="formula">
DW_AT_location   where the argument was, at the moment of the call
                 a location expression, evaluated against the
                 register state BEFORE the call

DW_AT_call_value what the argument was
                 a value expression, also evaluated against the
                 register state BEFORE the call
</div>
                <p>The pairing is the whole idea, and it is easy to get backwards. <code>DW_AT_location</code> answers "which register held it", which is a <em>location</em> question of exactly the kind the <a href="/courses/dwarf/lessons/dwarf-locations">location expressions concept</a> covered. <code>DW_AT_call_value</code> answers "what was in it", and it is a separate expression because at <code>-O2</code> the argument is very often not a simple register at all &mdash; it is <code>rbx - 1</code>, or a constant, or something the optimiser computed into a scratch register. Conflating them produces a debugger that reports the right register and the wrong value, which is the worst of both.</p>
                <div class="callout callout-warn">
                    <strong>The evaluation point is the trap.</strong> Both expressions are evaluated against the register state <em>before</em> the call instruction, not the state you have now. You are reconstructing a moment that has passed, using data captured at that moment. A reader that evaluates <code>DW_AT_call_value</code> against the current register file gets whatever happens to be in that register now, which is a different number on every run. This is the same class of mistake as the <code>DW_OP_entry_value</code> pitfall in the location-lists concept, reached from the opposite direction.
                </div>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>Three lines of C, compiled at <code>-O2</code>:</p>
                <p>Three functions, every body a single expression:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Function</th><th scope="col">Body</th></tr>
                    </thead>
                    <tbody>
                        <tr><td><code>g</code></td><td>declared only, defined elsewhere</td></tr>
                        <tr><td><code>f(n)</code></td><td>initialise a sum to zero, then loop adding <code>g(i)</code> for <code>i</code> from 0 while <code>i</code> is below <code>n</code></td></tr>
                        <tr><td><code>main</code></td><td><code>return f(3)</code></td></tr>
                    </tbody>
                </table>
                <pre><code>$ gcc -gdwarf-5 -O2 -c calls.c -o calls_O2.o</code></pre>
                <p>That last line is the whole experiment. <code>return f(3)</code> is a <em>tail call</em> in the source language's own terms &mdash; the result of <code>f</code> becomes the result of <code>main</code> with no work left to do afterwards &mdash; so an optimiser is free to compile it as a jump. Whether it does is exactly what the rest of this concept is about.</p>
                <h3>The DIE subtree, and the machine code it describes</h3>
                <p>Read these two side by side. The debug information on the left, the disassembly of <code>main</code> on the right:</p>
                <div class="hex-dump">
                    <pre>&lt;1&gt;&lt;4a&gt; DW_TAG_subprogram  main
    &lt;5e&gt;  DW_AT_high_pc        : 0xe
    &lt;68&gt;  DW_AT_call_all_calls : 1
    &lt;68&gt;  DW_AT_sibling        : &lt;0x80&gt;
  &lt;2&gt;&lt;6c&gt; DW_TAG_call_site
    &lt;6d&gt;    DW_AT_call_return_pc : 0xe
    &lt;75&gt;    DW_AT_call_tail_call : 1
    &lt;75&gt;    DW_AT_call_origin    : &lt;0x80&gt;
  &lt;3&gt;&lt;79&gt;   DW_TAG_call_site_parameter
    &lt;7a&gt;      DW_AT_location     : 1 byte block: 55   (DW_OP_reg5 rdi)
    &lt;7c&gt;      DW_AT_call_value   : 1 byte block: 33   (DW_OP_lit3)
  &lt;3&gt;&lt;7e&gt;   Abbrev Number: 0        (end of children)
  &lt;2&gt;&lt;7f&gt; Abbrev Number: 0          (end of children)
&lt;1&gt;&lt;80&gt; DW_TAG_subprogram  f         &lt;- DW_AT_call_origin points here
</pre>
                </div>
                <div class="hex-dump">
                    <pre>0000000000000000 &lt;main&gt;:
   0:  f3 0f 1e fa    endbr64
   4:  bf 03 00 00 00  mov    $0x3,%edi
   9:  e9 00 00 00 00  jmp    e &lt;main+0xe&gt;
</pre>
                </div>
                <p>Every field has a counterpart in those three instructions. Work through them:</p>
                <ol>
                    <li><strong><code>DW_AT_high_pc : 0xe</code> and the function is 14 bytes.</strong> <code>0xe</code> = 14, and the last instruction ends at offset 9 + 5 = 14. Consistent. (And <code>high_pc</code> is a <em>length</em> here, not an address &mdash; the rule from the previous concept.)</li>
                    <li><strong><code>DW_AT_call_tail_call : 1</code> and the instruction is <code>jmp</code>, not <code>call</code>.</strong> This is the field that says so, and the disassembly confirms it. The compiler turned <code>return f(3)</code> into a jump, so <code>main</code>'s own frame is never torn down and the callee reuses it.</li>
                    <li><strong><code>DW_AT_call_origin : &lt;0x80&gt;</code> points at <code>f</code>'s subprogram DIE</strong> &mdash; the <em>definition</em>, fourteen bytes later in the file. A forward reference, which is worth noticing: DIE offsets are not required to point backwards, and a reader that assumes they do will fail here.</li>
                    <li><strong><code>DW_AT_location : 55</code> is <code>DW_OP_reg5</code> = <code>rdi</code></strong> &mdash; and the instruction is <code>mov $0x3,%edi</code>. The argument was in the first integer argument register. Correct.</li>
                    <li><strong><code>DW_AT_call_value : 33</code> is <code>DW_OP_lit3</code></strong> &mdash; the argument was the literal <code>3</code>. And the instruction is <code>mov $0x3,%edi</code>: the literal three, moved into the register. <strong>The debug info says the value was 3 and the machine code says the value 3 was loaded. Nothing here needed to be taken on trust.</strong></li>
                    <li><strong><code>DW_AT_call_return_pc : 0xe</code></strong> is the address just past the <code>jmp</code> &mdash; where a <code>call</code> would have returned. For a tail call that address is never executed, because there is no return. It is recorded anyway, because the format has one field for the concept and the tail-call flag qualifies it.</li>
                </ol>
                <p>That last point is the subtle one. <code>DW_AT_call_return_pc</code> is <em>not</em> "the return address of this frame" in the tail-call case; it is a synthetic address derived from the call site, and a debugger that puts it in the frame's return-address slot will produce a backtrace that points into the middle of <code>main</code>'s padding. The tail-call flag is what tells it not to.</p>
                <h3>A computed argument</h3>
                <p>The call inside <code>f</code> is more interesting, because the argument is not a constant:</p>
                <pre><code>&lt;3&gt;&lt;d3&gt; DW_TAG_call_site
  &lt;d4&gt;   DW_AT_call_return_pc : 0x2a
  &lt;dc&gt;   DW_AT_call_origin    : &lt;0x2f&gt;
&lt;4&gt;&lt;e0&gt;   DW_TAG_call_site_parameter
  &lt;e1&gt;     DW_AT_location   : 1 byte block: 55        (DW_OP_reg5 rdi)
  &lt;e3&gt;     DW_AT_call_value : 2 byte block: 73 7f     (DW_OP_breg3 rbx : -1)</code></pre>
                <p>Decode the two bytes by hand, because this is the SLEB128 trap from the location-expressions concept arriving in a new place. Opcode <code>0x73</code> is <code>DW_OP_breg3</code> &mdash; push the value of register 3 plus a signed operand. The operand is <code>0x7f</code>. Its high bit is set, so it continues &mdash; and there is no next byte, so the value is complete and the sign is bit 6, which is set. So it is negative, with magnitude <code>0x7f &amp; 0x3f = 63</code>, giving <strong><code>rbx - 1</code></strong>.</p>
                <p>Read as unsigned, <code>0x7f</code> is 127, and the debugger reports that the call to <code>g</code> was passed <code>rbx + 127</code>. That is a plausible number, it is the wrong number, and it is wrong on every single call. This is the identical failure the location-expressions concept warned about, and it is worth meeting twice: the first time it is a warning, the second time it is a habit.</p>
                <p>Now the <code>DW_AT_call_origin</code> here, <code>&lt;0x2f&gt;</code>. Look at what is at that offset:</p>
                <pre><code>&lt;1&gt;&lt;2f&gt; DW_TAG_subprogram
   &lt;30&gt;   DW_AT_name        : g
   &lt;39&gt;   DW_AT_declaration : 1        &lt;- a DECLARATION, not a definition
   &lt;39&gt;   DW_AT_prototyped  : 1
   &lt;3d&gt;   (a formal_parameter child)
   (no DW_AT_low_pc, no DW_AT_high_pc)</code></pre>
                <p>So <code>DW_AT_call_origin</code> points at a <em>declaration</em> in this case and at a <em>definition</em> in <code>main</code>'s case. <strong>It names the thing being called, not the kind of call.</strong> Whether the call was a tail call is <code>DW_AT_call_tail_call</code>, full stop. A reader that distinguishes tail calls by inspecting the origin DIE's contents is using the wrong field, and it will get the ordinary calls in <code>f</code> wrong.</p>
                <h3>The two fallbacks</h3>
                <p>Both subprograms carry <code>DW_AT_call_all_calls : 1</code>. That is a statement about what to do when you have a return address and <em>no matching call site</em> &mdash; a frame from a function whose call-site information was not emitted, or a return address the optimiser invented. The rule is: attribute it to this function, and say you do not know which call it was. A tool that guesses a specific call site instead produces a backtrace that looks precise and is not.</p>
                <p>And note what is <em>not</em> in the tree. There is no <code>DW_AT_frame_base</code> override, no location list, and no <code>.debug_loclists</code> involvement. Call-site information is entirely inside <code>.debug_info</code>, which is worth knowing because it means a producer can emit it cheaply, with no extra sections and no relocations. Compare the <code>-O2</code> function <code>f</code>, whose <em>variables</em> need <code>.debug_loclists</code> because their locations vary per address range: the call sites need nothing, because a call site is a single point in the code rather than a range.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Turning a return address into a call, which is the whole point of the section. This is the inner loop of a stack unwind that wants to print arguments:</p>
                <div class="formula">
given: a return address RA, and the subprogram DIE it falls inside

1. find the DW_TAG_call_site child of that subprogram whose
   DW_AT_call_return_pc equals RA
   (a range match, not equality, is the usual rule -- a call site
    covers the return addresses its calls can produce)

   no match?  look for DW_AT_call_all_calls on the subprogram
              report "called from somewhere in this function"
              and stop -- do not guess a specific site

2. read DW_AT_call_tail_call
   if present and 1:
       this frame is a tail call. do NOT treat
       DW_AT_call_return_pc as a real return address.

3. resolve DW_AT_call_origin to the callee DIE
   a declaration  -> the call is ordinary
   a definition   -> ambiguous; trust DW_AT_call_tail_call,
                     not the origin's contents

4. for each DW_TAG_call_site_parameter child:
       where = evaluate DW_AT_location   against the pre-call registers
       value = evaluate DW_AT_call_value  against the pre-call registers
       report the parameter name from the callee's
       formal_parameter list, matched by position
</div>
                <p>Three things in that loop are easy to get wrong, and each has a symptom that looks like something else.</p>
                <p><strong>Step 4's evaluation point.</strong> Both expressions run against the pre-call register state, which the unwinder has to reconstruct from the call frame. If you evaluate against the current state you get a different answer every run, and the answer will be plausible &mdash; a register number, an integer. This is the failure that produces bug reports of the form "the debugger shows the wrong argument value, but only sometimes".</p>
                <p><strong>Step 1's "no match" branch.</strong> Falling back to <code>DW_AT_call_all_calls</code> and saying "somewhere in this function" is correct; picking the nearest call site by address is not. A backtrace is a claim about control flow, and a fabricated call site is a fabricated claim about control flow. The <code>DW_AT_call_all_calls</code> field exists precisely so that a reader can be honestly vague, and being vague is what makes the specific answers trustworthy.</p>
                <p><strong>Step 2's tail-call case.</strong> This is where a stack unwinder most often goes wrong, and the reason is structural rather than a bug: <strong>a tail call removes a frame that the CFI in <a href="/courses/dwarf/lessons/dwarf-frames">the frames concept</a> still describes.</strong> The unwind rules are generated for the function as written, and a tail call means the frame you are looking at belongs to the <em>caller</em>. The call-site information is the only place that says so, and <code>DW_AT_call_tail_call</code> is the only place it says so. Without reading it, an unwinder prints one frame too many, or attributes a frame to a function that was never on the stack.</p>
                <p>And the reason the whole thing is worth a format feature rather than a line-number lookup: <strong>the line number cannot answer it.</strong> <code>.debug_line</code> maps an address to a source line, so for a tail call it will confidently tell you the return address is on the line <code>return f(3)</code> in <code>main</code> &mdash; which is true and useless, because the interesting fact is that <code>main</code>'s frame was replaced rather than pushed. Line information describes position. Call-site information describes <em>what happened</em>, and only the second can tell you that a frame does not exist.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ gcc -gdwarf-5 -O2 -c calls.c -o calls_O2.o
$ objdump -d --section=.text calls_O2.o | sed -n '/&lt;main&gt;:/,/^$/p'
$ readelf --debug-dump=info calls_O2.o | grep -A6 DW_TAG_call_site</code></pre>
                <ul>
                    <li><strong>Kill the tail call and watch the flag change.</strong> Compile with <code>-O0</code> and with <code>-foptimize-sibling-calls</code> explicitly off. The <code>jmp</code> becomes a <code>call</code>, and <code>DW_AT_call_tail_call</code> should disappear. Then confirm <code>DW_AT_call_return_pc</code> is still present and still equal to the address after the call. That isolates what the flag adds, and it is one flag away from a build you control.</li>
                    <li><strong>Force a real call site at <code>-O0</code>.</strong> At <code>-O0</code> the call site usually vanishes entirely because the debugger can reconstruct the arguments from the stack. Find a case where it survives anyway &mdash; a tail call is the reliable one &mdash; and notice that the interesting information exists at both optimisation levels but for opposite reasons.</li>
                    <li><strong>Break the SLEB128 decoder deliberately.</strong> Change your reader to treat the <code>0x7f</code> operand as unsigned and confirm the reported value for <code>g</code>'s argument changes from <code>rbx - 1</code> to <code>rbx + 127</code>. Then confirm the disassembly of <code>f</code> is consistent with the first and not the second. Meeting a bug you built on purpose teaches the symptom better than meeting one you did not.</li>
                    <li><strong>Find a call site whose argument is a constant folded away.</strong> Compile with more inlining and look for a <code>DW_AT_call_site_parameter</code> whose <code>DW_AT_call_value</code> is a bare <code>DW_OP_litN</code> with no <code>DW_AT_location</code> at all. That is the format's way of saying "the value is known and there is no location", and it is the case a naive reader that requires both attributes gets wrong.</li>
                    <li><strong>Write the lookup loop above and test it.</strong> Extend the decoder shipped with this course to find a call site by return address, and check that it picks the right one for both the tail call and the ordinary call. Then delete the <code>DW_AT_call_tail_call</code> check and confirm the frame attribution goes wrong. The bug you introduce is the one you will recognise later.</li>
                    <li><strong>Compare with a C++ build.</strong> The deduplication in <a href="/courses/dwarf/lessons/dwarf-type-units">type units</a> and the merging of identical functions both interact with call sites: two call sites that compile to the same code may end up sharing one. Compile the same source as C and as C++ at <code>-O2</code> and diff the call-site trees. Whatever the difference is, it is the optimiser's, not the format's.</li>
                </ul>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: a call site records <code>DW_AT_call_return_pc : 0x2a</code>, <code>DW_AT_call_origin : &lt;0x2f&gt;</code>, and one <code>DW_TAG_call_site_parameter</code> with <code>DW_AT_location</code> = <code>55</code> and <code>DW_AT_call_value</code> = <code>73 7f</code>. The DIE at <code>&lt;0x2f&gt;</code> is a <code>DW_TAG_subprogram</code> with <code>DW_AT_declaration : 1</code> and no <code>DW_AT_low_pc</code>. What does <code>73 7f</code> say, and was this a tail call?</p>
                <div class="quiz" id="quiz-dwarf-call-sites-1">
                    <button class="quiz-option" data-correct="true" data-explain="Two independent readings. The value decodes as DW_OP_breg3 with a single-byte SLEB128 operand 0x7f: the high bit is set so the value is complete, and bit 6 is set so it is negative, with magnitude 0x7f and 0x3f = 63, giving rbx - 1. Read unsigned it would be 127 and every call would report the wrong argument. The tail-call question is answered by the absence of DW_AT_call_tail_call, not by the origin: DW_AT_call_origin names the thing being called, and in main's case it pointed at a definition while here it points at a declaration, which is the ordinary case. Using the origin's contents to decide would misclassify this call as a tail call." onclick="checkQuiz('quiz-dwarf-call-sites-1', this)">The value is <code>rbx - 1</code>, and this was <strong>not</strong> a tail call. The <code>0x7f</code> is a one-byte negative SLEB128, and no <code>DW_AT_call_tail_call</code> is present. The origin pointing at a <em>declaration</em> is the ordinary case, not the tail-call marker</button>
                    <button class="quiz-option" data-correct="false" data-explain="That is the SLEB128 sign bug, and it is the single most common way to misread these expressions. The high bit of 0x7f is set, which is what says the value continues, and with no following byte the value is complete; bit 6 being set is what makes it negative. The magnitude is 0x3f = 63, so the value is 63 - 64 = -1, not 127. The result is a plausible number that is wrong on every call, which is why the decoder has to be signed." onclick="checkQuiz('quiz-dwarf-call-sites-1', this)">The value is <code>rbx + 127</code>, and it <strong>was</strong> a tail call, because the origin points at a subprogram DIE rather than a declaration</button>
                    <button class="quiz-option" data-correct="false" data-explain="Both halves are inverted, and the value half is the more consequential error. The operand 0x7f has bit 6 set, so it is negative, and its magnitude is 63, giving rbx minus 1. And a subprogram DIE at the origin does not indicate a tail call at all: in main's case the origin pointed at a definition and that was the tail call, while here it points at a declaration, which is the ordinary case. DW_AT_call_tail_call is the only field that answers the tail-call question." onclick="checkQuiz('quiz-dwarf-call-sites-1', this)">The value is <code>rbx - 1</code>, and it <strong>was</strong> a tail call, since <code>DW_AT_call_origin</code> names a subprogram that has no <code>DW_AT_low_pc</code></button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Your debugger's backtrace is one frame too deep on some functions built at <code>-O2</code>, and only on those. The innermost frames show a function that the source says has already returned, and its locals are garbage. Everything else about the debug info reads correctly: right source lines, right types, right variable values. The same build at <code>-O0</code> backtraces perfectly. What is happening, and what is the smallest change that fixes it?</p>
                <div class="quiz" id="quiz-dwarf-call-sites-2">
                    <button class="quiz-option" data-correct="true" data-explain="The pattern points straight at it. One frame too deep, only at -O2, with the extra frame belonging to a function that has already returned, is the textbook signature of a tail call: the caller performed a jump instead of a call, so the callee reused the caller's frame and the caller's frame no longer exists on the stack. The CFI still describes it, which is why the unwinder faithfully produces a frame that is not there, and the locals read as garbage because that frame was never initialised. The smallest fix is to read DW_AT_call_tail_call from the call site and stop emitting a frame for it. It is a small change because the information is already there and correct: this concept verified it field by field against three instructions of machine code. Note what the symptom is not: it is not a wrong line number or a wrong type, so suspecting the line program or the DIE parser would be chasing the wrong subsystem entirely." onclick="checkQuiz('quiz-dwarf-call-sites-2', this)">The optimiser turned some calls into tail calls, so the caller's frame was replaced rather than pushed, and your unwinder is producing a frame the CFI describes but the machine never created. Read <code>DW_AT_call_tail_call</code> and do not emit a frame for a tail call</button>
                    <button class="quiz-option" data-correct="false" data-explain="Worth ruling out, and the reported symptom is the wrong one. A frame that is one too deep is a control-flow question: how many frames were pushed. A wrong line number is a position question, and position information is not what determines frame count. The build difference is the real clue here, and it points at the optimiser, not at the reader that maps addresses to lines." onclick="checkQuiz('quiz-dwarf-call-sites-2', this)">The line number program is misreporting the address after a call, so the unwinder is stopping one instruction late and picking up a line from the wrong function</button>
                    <button class="quiz-option" data-correct="false" data-explain="This confuses two different things sharing the word inlined. An inlined call leaves no frame at all, and DWARF records that with DW_TAG_inlined_subroutine inside the caller's subprogram, which the scopes concept already covered. A tail call does leave a frame, just not the one the CFI attributes it to. The distinction matters because the fix differs: for inlining you look inside the subprogram, for a tail call you consult the call site." onclick="checkQuiz('quiz-dwarf-call-sites-2', this)">The optimiser inlined some calls, and the inline information does not create a frame, so your unwinder is walking into a callee that was never called</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: when a debugger's frame count is wrong, the question is control flow, not position. Line information answers where you are; only call-site and frame information answers how you got there, and those live in different places.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Call-site information is the third thing DWARF does with a return address, and the three live in different sections for a reason worth naming. <a href="/courses/dwarf/lessons/dwarf-address-to-line">The line program</a> maps an address to a source position. <a href="/courses/dwarf/lessons/dwarf-frames">The CFI</a> says what a frame looks like at an address. <strong>Call sites say what a frame is the result of.</strong> Together they are the three questions a backtrace answers, and a tool that consults only the first two will produce plausible, correctly-located, structurally-wrong backtraces &mdash; which is the most expensive kind of wrong answer to receive.</p>
                <p>The tail-call case is the sharpest illustration of why the CFI is not sufficient on its own, and it is the same structural point that <a href="/courses/dwarf/lessons/dwarf-scopes">the scopes concept</a> made about inlining. Inlining means code from another function appears in this frame; tail calls mean this frame's contents belong to another function. Both are invisible in the machine code's control flow and both must be recorded out of band, because the frame's <em>contents</em> and its <em>provenance</em> are genuinely different facts.</p>
                <p>One thing remains, and it is the other kind of question this module has been asking. <a href="/courses/dwarf/lessons/dwarf-portability">Portability</a> asked which numbers a file states about itself. The last concept asks about a section that exists in some versions and not others, carries a completely different encoding, and has a name that matches the rest of the debug sections while behaving like none of them: <code>.debug_frame</code>, against the <code>.eh_frame</code> the frames concept decoded.</p>
                <p>Next: <a href="/courses/dwarf/lessons/dwarf-frame">The Other Unwind Section</a>.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/dwarf/lessons/dwarf-type-units">Previous: Type Units</a></span>
                <span><a href="/courses/dwarf/lessons/dwarf-frame">Next: The Other Unwind Section</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
