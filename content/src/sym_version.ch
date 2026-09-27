// Symbol Resolution and Symbol Tables — Module 4: Versions and Invented Symbols
// Concept: three tables, a parent chain, and a hash reused a third time.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_sym_version() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Versioned Symbols — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson sym-lesson">
            <a href="/courses/sym" class="back-link">Back to course</a>
            <h1>Versioned Symbols</h1>
            <div class="lesson-meta">26 min &middot; Module 4: Versions and Invented Symbols &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>In 2012 glibc replaced its <code>malloc</code> with a thread-safe implementation that used more memory and was slower on some workloads. Every program on every distribution broke. The fix is the subject of this concept, and it is a solution you can look up in any binary on your machine:</p>
                <div class="hex-dump">
                    <pre>$ readelf --dyn-syms -W /lib/x86_64-linux-gnu/libc.so.6 | grep -E ' (malloc|free)@'
  1391: ... FUNC GLOBAL DEFAULT UND malloc@GLIBC_2.2.5 (5)
  1937: ... FUNC GLOBAL DEFAULT UND free@GLIBC_2.2.5 (5)
</pre>
                </div>
                <p><strong><code>malloc@GLIBC_2.2.5</code> is not the name of a function. It is a name plus a requirement.</strong> The program is saying &ldquo;give me the <code>malloc</code> from the 2.2.5 era&rdquo;, and the library is free to provide an entirely different implementation as long as it provides <em>that</em> one too. Both versions live in the same library at once, and a program from 2004 keeps getting the behaviour it was compiled against.</p>
                <p>There is no way to do that with a plain name. A name is one thing; this needs one name to be several things, addressable independently, while remaining one name to the source language.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Three tables, and it is worth being precise about which side each belongs to, because &ldquo;versioning&rdquo; covers both directions and they are not symmetric.</p>
                <div class="formula">
  .gnu.version      2 bytes per .dynsym entry: an INDEX.
                    This is the per-symbol annotation. It is
                    what a reference points at.

  .gnu.version_d    verdef: the versions THIS FILE DEFINES.
                    A tree, linked by parent pointers.

  .gnu.version_r    verneed: the versions this file REQUIRES,
                    grouped by the file they come from.
                    This is a list of demands, not a table.
</div>
                <p>The index in <code>.gnu.version</code> is a <strong>version node number</strong>, and it means different things depending on which side of the file you are on. For a <em>defined</em> symbol it names the version this definition belongs to. For an <em>undefined</em> symbol it names a <em>required</em> version, resolved through <code>.gnu.version_r</code> into a requirement on a named file.</p>
                <p>So the two structures are genuinely different in kind. <code>verdef</code> is a <strong>tree</strong>: version 3 inherits from version 2, which inherits from version 1, and the chain is what makes &ldquo;anything that works with V1 also works with V3&rdquo; a checkable statement. <code>verneed</code> is a <strong>list</strong>: this file needs these versions of these names from these libraries. There is no inheritance in a requirement, because a requirement is a fact about one specific reference.</p>
            </div>

            <div class="unit unit-reality">
                <h2>Does It Actually Work?</h2>
                <p>Decode <code>.gnu.version_d</code> from a real versioned library:</p>
                <div class="hex-dump">
                    <pre>$ python3 symtables.py ver/libv.so
-- .gnu.version_d: what this file DEFINES --
    ndx=1  flags=BASE  hash=0x02f995ef  cnt=1
        verdaux[0] = 'libv.so'         own name
        elf_hash('libv.so') = 0x02f995ef  MATCHES vd_hash
    ndx=2  flags=none  hash=0x00000591  cnt=1
        verdaux[0] = 'V1'              own name
        elf_hash('V1') = 0x00000591     MATCHES vd_hash
    ndx=3  flags=none  hash=0x00000592  cnt=2
        verdaux[0] = 'V2'              own name
        verdaux[1] = 'V1'              PARENT
    ndx=4  flags=none  hash=0x00000593  cnt=2
        verdaux[0] = 'V3'              own name
        verdaux[1] = 'V2'              PARENT
</pre>
                </div>
                <p><strong>Finding 11: <code>vd_cnt</code> is not a name count.</strong> The <code>cnt</code> for V2 and V3 is 2, and a reader who takes it as &ldquo;this version has two names&rdquo; will be wrong. <strong>The last <code>verdaux</code> of a node is its parent version name, and that entry is counted.</strong> A node with a parent therefore always has <code>cnt &gt;= 2</code>, and V1 &mdash; the root &mdash; has <code>cnt = 1</code>.</p>
                <p>And <strong>Finding 12: <code>vd_hash</code> is the plain ELF hash.</strong> The same function <code>.hash</code> and <code>.gnu.hash</code> use, verified four times over including the SONAME. This is not a coincidence and it is load-bearing: <strong>the loader can reject a version mismatch with a 32-bit comparison instead of a string comparison</strong>, before doing any lookup. Note that the consecutive values 0x591, 0x592, 0x593 prove nothing by themselves &mdash; <code>V1</code>, <code>V2</code> and <code>V3</code> differ in one character. The proof is the SONAME hash, 0x02f995ef, which is not near its neighbours.</p>
                <p>Now the requirement side, from the same library:</p>
                <div class="hex-dump">
                    <pre>-- .gnu.version_r: what this file REQUIRES --
    from libc.so.6
      name=GLIBC_2.2.5   hash=0x09691a75   flags=0   other=5
</pre>
                </div>
                <p><strong>One requirement, from one file, naming one version.</strong> Compare its structure to the definition tree above: no parent, no chain, no hierarchy. A requirement is a flat assertion, and the &ldquo;other=5&rdquo; is the <em>index</em> that <code>.gnu.version</code> uses to point at it. <strong>The two tables are joined by a number, which is why they must be read together.</strong></p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Building a versioned library, and the three traps. First, the default version and its <code>@@</code> marker:</p>
                <div class="hex-dump">
                    <pre>$ cat ver/vmap
V1 { global: compute; local: *; };
V2 { global: added_in_v2; } V1;
V3 { global: compute; added_in_v2; removed_in_v3; vtag; } V2;

$ clang -fPIC -shared -Wl,--version-script=ver/vmap -o libv.so ver/vlib.c
$ llvm-nm -D --defined-only libv.so
0000000000000000 A V1@@V1
0000000000000000 A V2@@V2
0000000000000000 A V3@@V3
0000000000001110 T added_in_v2@@V2
0000000000001100 T compute@@V1
0000000000001120 T removed_in_v3@@V3
0000000000001130 T vtag@@V3
</pre>
                </div>
                <p><strong>Trap one, and it is silent.</strong> <code>compute</code> is listed in <code>global:</code> for <em>both</em> V1 and V3, and exactly one entry survives: <code>compute@@V1</code>. <strong>A symbol may belong to only one version node, and the first node that claims it wins. The later mention is discarded with no diagnostic.</strong> A library author who lists a symbol in every version expecting the latest to be the default gets the oldest one, silently.</p>
                <div class="hex-dump">
                    <pre>$ cat ver/vmap_at
V1 { global: compute@V1; local: *; };
$ clang -fPIC -shared -Wl,--version-script=ver/vmap_at -o /dev/null ver/vlib.c
ver/vmap_at:1: ignoring invalid character `@' in script
syntax error in VERSION script
</pre>
                </div>
                <p><strong>Trap two: <code>name@version</code> is not version-script syntax.</strong> That spelling is an assembly <code>.symver</code> directive. In a version script you list bare names and the linker decides the default. Anyone arriving from <code>.symver</code> will get this wrong, and the error message points at the character rather than the concept.</p>
                <div class="hex-dump">
                    <pre>$ clang -fPIC -shared -fvisibility=hidden \
      -Wl,--version-script=ver/vmap -o libh.so ver/vlib.c
$ llvm-nm -D --defined-only libh.so
0000000000000000 A V1@@V1
0000000000000000 A V2@@V2
0000000000000000 A V3@@V3
</pre>
                </div>
                <p><strong>Trap three, and this one connects straight back to <a href="/courses/sym/lessons/sym-visibility">Visibility Is Not Binding</a>.</strong> The script says <code>global: compute</code> and <code>compute</code> is <em>still not exported</em>. A version script can only <strong>narrow</strong> visibility, never confer it. <code>-fvisibility=hidden</code> has already demoted the binding to <code>LOCAL</code>, and a filter over the exported set cannot bring back something that is not in the set.</p>
                <p>That is three separate ways to write a version script and get a library that does not export what you expected, with two of them silent. <strong>The lesson is not about version scripts; it is that a version script is a filter with no diagnostic path, and a filter that silently drops entries is indistinguishable from a filter that worked.</strong></p>
            </div>

            <div class="unit unit-apply">
                <h2>Try It Yourself</h2>
                <div class="hex-dump">
                    <pre>$ cd courses/sym/assets/samples
$ ./build_samples.sh 2&gt;&amp;1 | sed -n '/Findings 11-15/,$p'
$ python3 symtables.py ver/libv.so
$ python3 crosscheck.py 2&gt;&amp;1 | sed -n '/\[11\]/,/^$/p'
</pre>
                </div>
                <p>Then break each structure deliberately, which is the only way to learn what a field is for:</p>
                <div class="hex-dump">
                    <pre>  1. Decode .gnu.version_d by hand from the bytes. For
     V3, list every verdaux and say which is the parent.
     Then write the vd_cnt you would have PREDICTED and
     compare. Why is the real number one higher?

  2. elf_hash('V1')=0x591. What is elf_hash of a name
     one character longer? Does the +1 pattern in the
     file prove anything? (Hint: test the SONAME.)

  3. Write a version script where V3's parent is V1
     (skipping V2). Does the chain still work? What did
     you lose?

  4. Build the same library three ways -- default,
     -fvisibility=hidden, and a script with no global:
     clause -- and count the exports each time. Which
     filter has the widest effect?
</pre>
                </div>
                <p>Question 3 has the answer that matters most for design. <strong>The parent chain is not a convenience; it is how compatibility is expressed.</strong> A client that requires V1 is satisfied by a library that defines V3 <em>as long as V3 descends from V1</em>, because the requirement is checked against the chain rather than against the name. Break the chain and V3 no longer satisfies a V1 requirement &mdash; you have created a new, incompatible library that happens to reuse a name. That is the whole reason the field exists, and it is the same reason a <code>struct</code> you have extended with a new trailing field can be passed to old code and the reverse is not true.</p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>This is the largest concept in the course and it has three distinct ancestors. <a href="/courses/sym/lessons/sym-hash">Two Hash Tables, One Job</a> supplied the hash function that Finding 12 reuses, and the base-name rule it established is what makes a versioned lookup a single chain walk followed by a comparison. <a href="/courses/sym/lessons/sym-visibility">Visibility Is Not Binding</a> supplied trap three, and it is the concept that explains <em>why</em> a filter cannot re-export: the decision was made by demoting a binding, and filters operate downstream of that.</p>
                <p>Forward, the connection to <a href="/courses/sym/lessons/sym-copy-reloc">Who Owns the Storage</a> is the pairing this module promised. <strong>That concept is a symbol whose <em>storage</em> must change without relinking its users; this is a symbol whose <em>behaviour</em> must change without relinking its users.</strong> Both are the same problem &mdash; you cannot force a rebuild of every binary in the field &mdash; and the platform has exactly two answers. Version the name when the behaviour changes, and do not export storage when the ownership is ambiguous. glibc needed the first in 2012 and the second even more, which is a large part of why modern glibc exports functions and hides its variables.</p>
                <p>Back to the static half, versioning is the sharpest possible answer to the constraint that closed Module 2. <a href="/courses/sym/lessons/sym-duplicate">Two Definitions and One Tentative</a> observed that a format which lets each producer record a local decision needs those decisions to interoperate, or the decision has to move. COMMON moved it to the compiler and then broke every prebuilt library. <strong>Versioning moves it into the file and makes the compatibility relation explicit and checkable</strong> &mdash; the chain in <code>verdef</code> <em>is</em> the interoperability rule, written down where both sides can see it.</p>
                <p>And one connection outside the course, because the shape recurs constantly. <strong>Versioning is ABI evolution, and ABI evolution is the practice of changing a contract without being able to change everyone who depends on it.</strong> The same problem is solved by parallel namespacing in Python 3, by <code>std::</code> versioning in the C++ standard library, by Android&rsquo;s API levels, and by keeping a <code>libfoo.so.1</code> beside a <code>libfoo.so.2</code> in <code>/usr/lib</code>. The ELF mechanism is interesting because it puts several versions <em>inside one file</em> rather than in parallel files, which saves a file descriptor per version and makes the compatibility check part of loading rather than part of packaging. The cost is the complexity you have just read, and the reason it is worth paying is that the alternative does not scale to a system with thousands of independently-built binaries.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/sym/lessons/sym-copy-reloc">Previous: Who Owns the Storage</a></span>
                <span>Next: <a href="/courses/sym/lessons/sym-linker-defined">Symbols the Linker Invents</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
