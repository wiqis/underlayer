// Dynamic Linking and Shared Libraries — Module 2: Building a Library
// Concept: -fvisibility=hidden, version scripts, and the flag that breaks
// every caller.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_dyn_export() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Hiding Things, and the Trap — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson dyn-lesson">
            <a href="/courses/dyn" class="back-link">Back to course</a>
            <h1>Hiding Things, and the Trap</h1>
            <div class="lesson-meta">24 min &middot; Module 2: Building a Library &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>The previous concept left one symbol in <code>.dynsym</code> because the source happened to define one public function. Real libraries define dozens. What decides which of them the world can see is four separate mechanisms, and the most popular one has a trap in it that costs a day.</p>
                <div class="hex-dump">
                    <pre>$ cat vis.c
int  exported_one(void){ return 1; }
int  exported_two(void){ return 2; }
__attribute__((visibility("hidden"))) int hidden_one(void){ return 3; }
static int static_one(void){ return 4; }
int  calls_all(void){ return exported_one() + exported_two()
                           + hidden_one() + static_one(); }

$ clang -fPIC -shared -o vis_default.so vis.c
$ clang -fPIC -fvisibility=hidden -shared -o vis_hidden.so vis.c
$ nm -D --defined-only vis_default.so | awk '{printf "  %s ", $3}'; echo
  calls_all exported_one exported_two
$ nm -D --defined-only vis_hidden.so | awk '{printf "  %s ", $3}'; echo
  (nothing at all)
</pre>
                </div>
                <p><strong>Four functions. Two exported. Then zero.</strong> <code>-fvisibility=hidden</code> removed <code>calls_all</code> along with everything else, and it is a completely correct flag doing exactly what it says.</p>
                <p>And here is the trap, immediately:</p>
                <div class="hex-dump">
                    <pre>$ cat t.c
extern int calls_all(void);
int main(void){ return calls_all()==10?0:1; }

$ clang -o tv t.c ./vis_hidden.so
ld.bfd: tv: undefined reference to `calls_all'
</pre>
                </div>
                <p><strong>The library is unusable and the compiler said nothing.</strong> Not a warning, not a note &mdash; nothing. The mistake surfaces at the caller&rsquo;s link step, naming a symbol that the library author can see perfectly well in their own source.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Four mechanisms, and they are not alternatives &mdash; they are layers, applied in a fixed order.</p>
                <div class="formula">
  LAYER 1  THE LANGUAGE
     static            local binding. never in .dynsym,
                      under any flag. strongest, because
                      the symbol is not even global.

  LAYER 2  THE COMPILER
     __attribute__((visibility("hidden")))
                      per-symbol, the most precise tool
                      there is.

     -fvisibility=hidden
                      a DEFAULT for the whole
                      translation unit. every symbol that
                      would have been default-visible
                      becomes hidden unless marked.

  LAYER 3  THE LINKER SCRIPT / VERSION SCRIPT
     ... global: a; b;  local: *; 
                      a link-time list. can only NARROW
                      visibility, never widen it: -fhidden
                      beats a global: clause. (the sym
                      course measured this.)

  LAYER 4  THE LINKER FLAG
     -Wl,--exclude-libs,ALL
                      hides symbols from STATIC
                      archives you linked in, which is a
                      different problem from a library's
                      own symbols.

                </div>
                <p><strong>Layer 3 can only narrow, and that asymmetry is worth dwelling on.</strong> A version script saying <code>global: everything</code> cannot resurrect a symbol the compiler already made hidden, because by the time the script runs the symbol has no global binding to expose. The <a href="/courses/sym/lessons/sym-version">symbol-resolution course</a> measured this and it is a genuinely useful fact: <strong>visibility decisions are made left to right through the pipeline and a later stage cannot undo an earlier one.</strong></p>
                <p>And the correct pattern, which is the opposite of the one that causes the trap:</p>
                <div class="formula">
  DEFAULT-DENY, THEN MARK THE API

     -fvisibility=hidden   +   __attribute__((visibility("default")))
                                     on each exported name

  or, equivalently, with a version script:

     -fvisibility=hidden   +   a version script whose
                                 global: list names exactly
                                 the API

  why default-deny:
    - everything not on the list is invisible by
      construction, so a NEW function is private until
      you decide otherwise. the alternative -- default
      allow -- publishes every helper you write.
    - a published symbol is a permanent commitment. it
      can be interposed (previous concept), it is
      versioned and ABI-frozen, and someone will depend
      on it.

                </div>
            </div>

            <div class="unit unit-reality">
                <h2>Does It Actually Work?</h2>
                <p>All three builds, and what each one costs the caller:</p>
                <div class="hex-dump">
                    <pre>  build                          .dynsym                     caller
  ----------------------------  --------------------------  --------------------
  default                        calls_all exported_one      links, runs
                                exported_two
  -fvisibility=hidden            (nothing)                   DOES NOT LINK
  version script, local: *        exported_one@@V1            DOES NOT LINK
</pre>
                </div>
                <p><strong>Two of the three restricted builds are broken, and both are correct.</strong> The version script is not a subtle failure either &mdash; it exports <code>exported_one</code> and nothing else, so <code>calls_all</code> is missing for exactly the same reason. The difference is that one failure was a flag and the other was a file, and the diagnostic is identical in both cases: <em>undefined reference</em>.</p>
                <p>And the fix, which is identical in both cases and is the only correct one:</p>
                <div class="hex-dump">
                    <pre>$ cat vis2.c
int  exported_one(void){ return 1; }
int  exported_two(void){ return 2; }
__attribute__((visibility("hidden"))) int hidden_one(void){ return 3; }
static int static_one(void){ return 4; }
/* THIS LINE IS THE ENTIRE FIX */
__attribute__((visibility("default"))) int calls_all(void);
int calls_all(void){ return exported_one() + exported_two()
                           + hidden_one() + static_one(); }

$ clang -fPIC -fvisibility=hidden -shared -o vis_hidden2.so vis2.c
$ nm -D --defined-only vis_hidden2.so | awk '{printf "  %s ", $3}'; echo
  calls_all
$ clang -o tv2 t.c ./vis_hidden2.so -Wl,-rpath,'$ORIGIN' &amp;&amp; ./tv2 &amp;&amp; echo "  links, runs, correct"
  links, runs, correct
</pre>
                </div>
                <p><strong>One exported symbol, and it is the one the caller wanted.</strong> <code>hidden_one</code> and <code>static_one</code> are still called &mdash; internally, directly, with no interposition risk &mdash; and are still not in <code>.dynsym</code>. Nothing is broken and nothing extra is published.</p>
                <p>The version-script route gets the same result and adds versioning as a side effect, which is often the reason to prefer it:</p>
                <div class="hex-dump">
                    <pre>$ cat ver2.map
V1 { global: exported_one; calls_all; local: *; };

$ clang -fPIC -shared -Wl,--version-script=ver2.map -o vis_ver2.so vis2.c
$ nm -D --defined-only vis_ver2.so | awk '{printf "  %s ", $3}'; echo
  V1@@V1  calls_all@@V1  exported_one@@V1

$ readelf -VW vis_ver2.so | sed -n '/Version definition/,/^$/p'
  Version definition section '.gnu.version_d' contains 2 entries:
   000000: Rev: 1  Flags: BASE  Index: 1  Cnt: 1  Name: vis_ver2.so
    0x001c: Rev: 1  Flags: none  Index: 2  Cnt: 1  Name: V1
</pre>
                </div>
                <p><strong>The <code>@@V1</code> suffixes are not decoration either.</strong> A version script does two things at once: it selects which symbols are exported, and it assigns each a version. The version is what lets you later ship a <code>V2</code> of the same library while keeping <code>V1</code> working for programs linked against it &mdash; and it is the <a href="/courses/sym/lessons/sym-version">sym course&rsquo;s version-definition tables</a> being <em>generated</em> rather than read.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Why a published symbol is a commitment rather than a convenience, and the specific failure that follows from publishing the wrong one.</p>
                <div class="hex-dump">
                    <pre>  a library exports an INTERNAL helper by accident:

    static int format_error(char *buf, int n);   /* internal */
    int  public_api(const char *s){ ... }

  the helper was meant to be static. it was not, so it
  is in .dynsym, and now:

    - it is a candidate for interposition. any process
      that loads this library can redefine format_error
      and change what public_api does. (the previous
      concept, measured.)
    - it is ABI-frozen. you cannot change its signature
      without a soname bump, because someone might be
      calling it -- not on purpose, but because it is
      there and linkable.
    - it is in the documentation by accident, because
      doxygen reads .dynsym and not the source comments.

  the fix is not to remove it later. it is to not have
  published it: -fvisibility=hidden from the start, so
  the default is that nothing is public until it is
  chosen to be.
</pre>
                </div>
                <p><strong>That is the whole argument for default-deny, and it is an argument about time.</strong> Removing a published symbol later is a breaking change; not publishing it is invisible. <strong>The cost of the restrictive default is paid once, at the point where you mark your API; the cost of the permissive default is paid forever, by every future reader of your <code>.dynsym</code>.</strong></p>
                <p>And the version script&rsquo;s second job, which is the one that pays for the trouble it causes. A library with versions is what makes an upgrade safe:</p>
                <div class="hex-dump">
                <pre>  V1 { global: api_v1; api_v2; } V1;
  V2 { global: api_v1; api_v2; } V1;

  v1.0 ships V1 only.  a program links api_v1, records
  api_v1@@V1, and the loader binds that SPECIFIC VERSION.

  v2.0 adds api_v2 and keeps api_v1 at V1.  a program
  linked against v1.0 still binds api_v1@@V1, gets the
  new library, and nothing breaks -- because the version
  is part of the symbol's identity.

  remove api_v1 from V2 and the OLD program now fails to
  start, with a message naming a version rather than a
  symbol. which is a far better failure than a silent
  behaviour change.
</pre>
                </div>
                <p><strong>Versioning turns &ldquo;the symbol is missing&rdquo; into &ldquo;the version is missing&rdquo;</strong>, and that is the difference between a diagnosable upgrade and a mystery. The <a href="/courses/sym/lessons/sym-binding-time">sym course&rsquo;s eager-binding concept</a> noted that a symbol can be listed in two version nodes and only the first wins; this is the producing side of the same tables, and the rule that a version script can only narrow is what stops the producing side from contradicting the consuming side.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Try It Yourself</h2>
                <div class="hex-dump">
                    <pre>$ cd courses/dyn/assets/samples
$ ./build_samples.sh 2&gt;&amp;2 | sed -n '/D8/,/D9/p'
$ python3 crosscheck.py 2&gt;&amp;2 | sed -n '/\\[8\\]/,/\\[9\\]/p'
$ python3 dynscope.py exports liba.so
</pre>
                </div>
                <p>Then measure the cost of getting it wrong, which is the only way to believe the pattern:</p>
                <div class="hex-dump">
                    <pre>  1. Take vis_default.so, which exports three
     symbols, and a version script with local: *.
     How many symbols does the program break? (All the
     ones it did not name. Count them.)

  2. Now try to WIDEN with a version script: compile
     with -fvisibility=hidden, then pass
     { global: calls_all; local: *; }. Does the global
     clause bring it back? (It should not. Explain why
     in terms of what the linker has to work with.)

  3. Add a third function to vis2.c, one you forget to
     mark. It is now invisible. Is that better or worse
     than it being visible? Argue it both ways and
     decide which failure you would rather debug.

  4. Build a two-version library (V1 then V2) and link
     two programs, one against each. Use
     nm -D to see the version suffixes, then swap the
     library underneath the V1 program. Does it still
     run? (That is the entire point of versioning.)

  5. Take a real system library --
     /usr/lib/x86_64-linux-gnu/libm.so.6 -- and count
     its .dynsym. Then count how many of those are
     documented. (The ratio is the argument for
     default-deny, made by somebody else's code.)
</pre>
                </div>
                <p>Exercise 2 is the one that closes the loop on the sym course, and it is a five-minute experiment with a satisfying answer. <strong>A version script cannot resurrect a hidden symbol</strong>, and the reason is worth being able to state precisely: by the time the script is read, the symbol has no global binding and no dynamic index entry for the script to point at. The <code>global:</code> clause can only <em>narrow the set of global-visibility symbols</em>, and a hidden symbol is not in that set. <strong>Visibility is decided once, left to right, and a later stage has nothing to work with.</strong></p>
                <p>Exercise 5 is the one that makes the case for a library author rather than a student. <code>libm.so.6</code> exports a very large number of symbols relative to the number anyone calls, and the excess is decades of accumulated compatibility. <strong>Every one of those is a promise it must keep forever, and none of them would exist under default-deny.</strong> The argument for <code>-fvisibility=hidden</code> is not aesthetics; it is that the cost of a published symbol is paid by whoever maintains the library next, and the cost of a hidden one is paid by whoever wrote the code, once.</p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>This is the export half of the building module, and it exists because <a href="/courses/dyn/lessons/dyn-interpose">Interposition</a> established that a symbol in <code>.dynsym</code> is a candidate for a search every process on the system performs. <strong>Visibility is the mechanism by which a library opts out of that, and it is therefore a correctness tool rather than a packaging preference.</strong></p>
                <p>The connection to the <a href="/courses/sym/lessons/sym-visibility">symbol-resolution course&rsquo;s visibility concept</a> is a division of labour that only becomes clear once you have built something. That course measured the <em>encoding</em>: that <code>hidden</code> and <code>internal</code> demote the binding to <code>STB_LOCAL</code> and remove the symbol from <code>.dynsym</code> entirely, so for two of the four values the answer is not in <code>st_other</code> at all. <strong>This concept is the producing side of that measurement</strong> &mdash; the flags and the script that make the demotion happen &mdash; and it adds the thing the encoding cannot show: that the decision is one-way. A later pipeline stage has no way to widen what an earlier one narrowed, and that is why the restrictive default has to be chosen at compile time rather than at link time.</p>
                <p>Forward within the module, the next concept is the other half and the distinction is the point. <a href="/courses/dyn/lessons/dyn-symbolic">One Instruction Called -Bsymbolic</a> deals with a symbol that <em>is</em> exported and a call to it that should not be interposable. <strong>Hiding removes a name from the search space; <code>-Bsymbolic</code> removes a call from it.</strong> A library that hides its internals still has exported functions that call each other through the PLT, and those calls are still interposition candidates. Both concepts are about the same search, from opposite ends.</p>
                <p>And the version half of this concept connects forward to the run-time module, because a version is a second key in the same lookup. <a href="/courses/dyn/lessons/dyn-resolve">The artifact</a> in the last concept resolves plain names; resolving <code>api_v1@@V1</code> needs the <code>.gnu.version</code> table as well, and that is exactly the extension the sym course measured. <strong>Dynamic linking has one search and three keys &mdash; name, version, and binding strength &mdash; and every mechanism in this course is a variation on how one of them is chosen.</strong></p>
                <p>One connection outward, for the security framing. <a href="/courses/dyn/lessons/dyn-interpose">The interposition concept</a> described an attacker winning a name by getting a file onto the search path. <strong>That attack only works for names the library exports</strong>, so <code>-fvisibility=hidden</code> is a direct reduction in attack surface: a library that exports three symbols has three candidates, and one that exports thirty has thirty. The version suffix narrows it further, because <code>api_v1@@V1</code> is a different name from <code>api_v1</code> and an attacker exporting the bare name does not satisfy the request. <strong>Every mechanism in this concept is a way of making the search space smaller, and a smaller search space is both safer and faster.</strong></p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/dyn/lessons/dyn-build-so">Previous: Building a Library</a></span>
                <span>Next: <a href="/courses/dyn/lessons/dyn-symbolic">One Instruction Called -Bsymbolic</a></span>
            </div>
        </div>
    

    render_lesson_js(&mut page)
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
