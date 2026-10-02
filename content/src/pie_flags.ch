// Relocations, PIC and PIE — Module 2: Position Independent Executables
// Concept: -fPIC against -pie, and the binary that is neither.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_pie_flags() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Flags, and Which One Is Which Kind — Underlayer")
    page.appendTitle(&title)

    render_lesson_nav(&mut page)
    render_lesson_css(&mut page)

    #html {
        <div class="lesson reloc-lesson">
            <a href="/courses/reloc" class="back-link">Back to course</a>
            <h1>The Flags, and Which One Is Which Kind</h1>
            <div class="lesson-meta">19 min &middot; Module 2: Position Independent Executables &middot; Intermediate</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>There are four flags, they all contain &ldquo;pie&rdquo; or &ldquo;pic&rdquo;, and they do not all mean the same kind of thing. Here is the complete matrix, every row built and measured:</p>
                <div class="hex-dump">
                    <pre>$ for spec in "-fno-pic -fno-pie -no-pie" \
                "-fno-pic -fno-pie -pie" \
                "-fPIE -pie" \
                "-fPIE -no-pie" \
                "-fPIC -shared"; do
    fl="${spec%%:*}"; n="${spec#*:}"
    clang -O1 $fl -o p_$n tiny.c
    printf "  %-9s %-24s %s\n" "$n" "$fl" "$(readelf -hW p_$n|awk '/Type:/{print $2}')"
  done

  nopie     -fno-pic -fno-pie -no-pie   EXEC
  halfpie   -fno-pic -fno-pie -pie      DYN
  pie       -fPIE -pie                  DYN
  halfpie2  -fPIE -no-pie               EXEC
  picso     -fPIC -shared              DYN
</pre>
                </div>
                <p><strong>Read rows two and four. They are the interesting ones</strong>, because in each the two flags disagree and the result is a binary that is neither thing:</p>
                <div class="formula">
  -f  and  -f     ARE THE SAME KIND OF THING. both change
                  what the COMPILER emits. they are codegen.

  -pie  and  -no-pie  ARE THE SAME KIND OF THING. both
                  change what the LINKER produces. they are
                  link decisions, and they set e_type.

  A ROW IS COHERENT when the two agree about the answer
  to "will this be moved?".

    halfpie:  code says NO, file says YES
    halfpie2: code says YES, file says NO
</div>
                <p>Neither half-row is <em>wrong</em>, exactly. Both are build configurations someone can create by accident, and both work. But each one pays a cost without receiving the benefit, and that asymmetry is the whole subject of this concept.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Two independent questions, and it is worth being precise that they are asked at different times by different programs.</p>
                <div class="formula">
  Q1  COULD THIS CODE SURVIVE BEING MOVED?
      asked by the COMPILER, at -c time
      answered by: which relocation types it emits
      cost of answering YES: an extra indirection per
                           reference (measured in pie-cost)

  Q2  WILL THIS FILE ACTUALLY BE MOVED?
      asked by the LINKER, at link time
      answered by: e_type = ET_DYN or ET_EXEC
      cost of answering YES: none at run time, but the
                             loader must honour a random base

  Q1 and Q2 are the same question asked by two programs
  that cannot see each other. Nothing enforces agreement.

                </div>
                <p><strong>That last line is the whole concept.</strong> There is no mechanism by which <code>clang -fPIE</code> can check what <code>ld -no-pie</code> will do, and no mechanism by which the linker can check what the compiler emitted. They are separate processes making a correlated decision, and the correlation is maintained by a build system.</p>
                <p>Which brings up the two defaults, which are not the same on every distribution:</p>
                <div class="hex-dump">
                    <pre>  $ clang --version | head -1
  Ubuntu clang version 21.1.8

  $ clang -### -c tiny.c 2&gt;&amp;1 | grep -o 'fPIE\|fPIC\|fno-pie' | sort -u
  (this machine defaults to -fPIE for executables)

  $ clang -### -shared tiny.c 2&gt;&amp;1 | grep -o 'fPIC'
  (and to -fPIC for shared objects)
</pre>
                </div>
                <p>So on a modern distribution the <em>compiler default</em> is already position-independent, and <code>-no-pie</code> is a deliberate step backwards. That reverses the usual intuition, where PIE feels like something you opt into. <strong>Here it is the default and opting out is the unusual act.</strong></p>
            </div>

            <div class="unit unit-reality">
                <h2>Does It Actually Work?</h2>
                <p>Now the cost of the two incoherent rows, measured rather than asserted. Take the case the <a href="/courses/sym/lessons/sym-copy-reloc">symbol-resolution course</a> found and put a number on it:</p>
                <div class="hex-dump">
                    <pre>$ cat owner.c
extern int lib_data;
int main(void){ return lib_data ? 1 : 0; }

$ clang -O1 -fPIE   -no-pie -o halfpie2 owner.c -L. -lsym
$ readelf -rW halfpie2 | grep lib_data
  ... R_X86_64_GLOB_DAT   lib_data + 0      &lt;-- still going through the GOT

$ readelf -hW halfpie2 | awk '/Type:/{print "   and e_type is", $2}'
   and e_type is EXEC
</pre>
                </div>
                <p><strong>An <code>ET_EXEC</code> binary still carrying a <code>GLOB_DAT</code>.</strong> The address of <code>lib_data</code> is fixed at link time &mdash; the file says so &mdash; but the code was compiled to load that address from a GOT slot at runtime. The indirection is pure waste: the loader patches a slot whose value the linker already knew.</p>
                <p>And the reverse case, which costs an instruction on <em>every single call</em>:</p>
                <div class="hex-dump">
                    <pre>$ clang -O1 -fno-pic -fno-pie -pie -o halfpie tiny.c
$ readelf -hW halfpie | awk '/Type:/{print "   e_type is", $2}'
   e_type is DYN
$ readelf -rW halfpie | grep -c PLT32
   1
</pre>
                </div>
                <p>A <code>DYN</code> file whose code was compiled assuming a fixed layout. If the loader honours the random base the code expects, the program must not be moved &mdash; and on a system that does move <code>ET_DYN</code> files, <strong>the only thing keeping it working is that the loader happened to place it where the code assumed</strong>, which is a property of the default base, not a guarantee.</p>
                <p>That is the dangerous half-row, and the reason it deserves a warning. A <code>-fno-pic</code> object in a <code>DYN</code> file is a latent crash that works on your machine because your loader picks a conventional base address, and fails on a system where it does not. The next concept measures whether a coherent PIE actually moves; this is the case where one does not and should not.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>The mistake that actually happens, because it does not look like a mistake. A build system wants non-PIE binaries for compatibility with an old assumption, and writes:</p>
                <div class="hex-dump">
                    <pre>  # WRONG: fixes the link, not the code
  CFLAGS  += -fno-pie
  LDFLAGS += -no-pie
  # -> works, but the -fno-pie does nothing you wanted

  # RIGHT
  CFLAGS  += -fno-pie        # codegen: fixed-layout code
  LDFLAGS += -no-pie         # link:    ET_EXEC

  # ALSO RIGHT, and better
  CFLAGS  += -fno-pic -fno-pie
  LDFLAGS += -no-pie
</pre>
                </div>
                <p>The first version is the common one and it is <em>not harmless</em>, because <code>-fno-pie</code> on its own does not switch off PIC codegen &mdash; it switches off PIE codegen, and on this toolchain the default was PIE anyway, so the flag is very nearly a no-op. The binary ends up <code>ET_EXEC</code> with PIE-style GOT indirection. <strong>You asked for less position independence and got none of the benefit, because the flag you reached for is the wrong one.</strong></p>
                <p>The distinction that resolves it is a single question: <strong>does the flag change the bytes in the <code>.o</code>, or the bytes in the executable?</strong> Everything prefixed <code>-f</code> changes the object. Everything prefixed <code>-no</code>/<code>-shared</code>/<code>-pie</code> passed to the linker changes the executable. If you can answer that for a flag you are using, you can predict what it does.</p>
                <p>One more trap, and it is the one the symbol course found the hard way. The reverse &mdash; <code>-fPIE</code> compiled, <code>-no-pie</code> linked &mdash; produced the <code>GLOB_DAT</code> instead of the <code>COPY</code> that a genuinely non-PIE executable gets, because the code model decided the access sequence before the link model got a vote. <strong>One flag changed which relocation the loader is asked to process.</strong> That is the clearest possible demonstration that Q1 and Q2 are not merely separate but <em>consequential</em>: the code model picks the relocation, and the relocation decides how much work the loader does.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Try It Yourself</h2>
                <div class="hex-dump">
                    <pre>$ cd courses/reloc/assets/samples
$ ./build_samples.sh 2&gt;&amp;1 | sed -n '/F3/,/F4/p'
$ python3 crosscheck.py 2&gt;&amp;1 | sed -n '/\[3\]/,/\[4\]/p'
</pre>
                </div>
                <p>Then build the matrix yourself and predict each cell before you run it:</p>
                <div class="hex-dump">
                    <pre>  codegen \ link      -no-pie              -pie              -shared

  -fno-pic -fno-pie     EXEC, no GOT        ???                ???
  -fPIE                EXEC, GOT (measured) ???                ???
  -fPIC                ???                 ???                ???

  1. Fill in the nine cells: e_type, and whether a data
     reference goes through the GOT.

  2. Which of the nine are COHERENT, and what is the rule
     that decides coherence?

  3. Take the coherent -fPIE/-no-pie cell and the coherent
     -fno-pic/-no-pie cell. Which one is faster, and by
     roughly how much per data reference? (The next
     concept measures it; predict first.)

  4. Find a flag whose NAME suggests one kind and whose
     BEHAVIOUR is the other. (-fPIE vs -fPIC is the
     obvious one. Is there a worse one?)
</pre>
                </div>
                <p>Question 2 has the rule, and it is one sentence: <strong>a row is coherent when the code model and the file type agree on whether the image can move.</strong> Four of the nine cells are coherent, one is impossible (<code>-fno-pic</code> into <code>-shared</code> is the <a href="/courses/reloc/lessons/pic-violation">PIC violation</a>), and the remaining four are the incoherent configurations this concept is about. All four are constructible, all four run, and all four are mistakes.</p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>This opens the PIE module, and the connection back is the direct answer to a question the vocabulary module left open. <a href="/courses/reloc/lessons/reloc-why-so-many">Why There Are So Many Kinds</a> grouped the relocations and noted that <em>PIE and PIC emit the same vocabulary for the same source</em> &mdash; and said the difference was in what the loader may do with it. <strong>This concept is that difference, in the form of two flags that different processes read.</strong></p>
                <p>Within the module the chain is short and load-bearing. This concept establishes which binary you have. <a href="/courses/reloc/lessons/pie-randomize">Does the Executable Actually Move?</a> then checks the only question that matters about it, with six runs of each. <a href="/courses/reloc/lessons/pie-cost">What Position Independence Costs</a> puts a number on the answer, in instructions and bytes, so that &ldquo;should I?&rdquo; has a defensible answer rather than a slogan.</p>
                <p>The strongest connection is back to the symbol course, and it is a mechanism rather than a theme. <a href="/courses/sym/lessons/sym-copy-reloc">Who Owns the Storage</a> found that <code>R_X86_64_COPY</code> versus <code>R_X86_64_GLOB_DAT</code> is decided by the code model of the executable&rsquo;s translation unit, and that <code>-no-pie</code> at link time alone is not enough. <strong>This concept explains why that was surprising: the answer was being chosen by a flag three compilation steps away, and the flag that &ldquo;sounds&rdquo; like the right one does not make the decision.</strong> Two courses, one mechanism, and the reason it is worth learning twice is that the failure is silent in both cases &mdash; a working binary with a cost you did not ask for, or a working binary that will break on a machine that is not yours.</p>
                <p>Forward into the failure module, the incoherent <code>-fno-pic</code>-into-<code>-shared</code> cell is the one cell the flag matrix cannot legalise, and <a href="/courses/reloc/lessons/pic-violation">The Relocation That Cannot Be Fixed</a> is about what happens there. The distinction to carry forward is between a configuration that is <strong>incoherent but legal</strong> &mdash; the four cells above, all of which link and all of which run &mdash; and one that is <strong>incoherent and rejected</strong>. Only the second produces a diagnostic, and a course that teaches only the second leaves you unprotected against the first.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/reloc/lessons/reloc-encoding-limits">Previous: The Limits That Shaped the Table</a></span>
                <span>Next: <a href="/courses/reloc/lessons/pie-randomize">Does the Executable Actually Move?</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
