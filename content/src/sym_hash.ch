// Symbol Resolution and Symbol Tables — Module 3: Resolution at Runtime
// Concept: the two hash tables, and the layout of the GNU one that is not what
// you would guess.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_sym_hash() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Two Hash Tables, One Job — Underlayer")
    page.appendTitle(&title)

    render_lesson_nav(&mut page)
    render_lesson_css(&mut page)

    #html {
        <div class="lesson sym-lesson">
            <a href="/courses/sym" class="back-link">Back to course</a>
            <h1>Two Hash Tables, One Job</h1>
            <div class="lesson-meta">24 min &middot; Module 3: Resolution at Runtime &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>A dynamic loader is given several libraries and a name, and must find the definition in time to patch a call site. <strong>It cannot scan, because scanning is linear and a process resolves thousands of names</strong>. It needs a lookup structure, and ELF has had two answers to this question for thirty years &mdash; and the one your compiler emits today is not the one most textbooks describe.</p>
                <div class="hex-dump">
                    <pre>$ clang -O1 -o prog tiny.c
$ readelf -SW prog | grep -E '\.hash'
  [ 3] .gnu.hash   GNU_HASH   ...
$ readelf -SW prog | grep -cE ' \.hash '
0                       &lt;-- .hash is ABSENT. Not deprecated, absent.
</pre>
                </div>
                <p>So any course text that says &ldquo;the hash table&rdquo; and then walks you through <code>.hash</code> is describing a section your <code>ld</code> will not produce unless you ask. The three build styles:</p>
                <div class="hex-dump">
                    <pre>$ for s in sysv gnu both; do
    clang -O1 -Wl,--hash-style=$s -o hs_$s tiny.c
    printf "%-5s %s\n" $s "$(readelf -SW hs_$s | grep -oE '\.gnu\.hash|\.hash' | sort -u | tr '\n' ' ')"
  done
sysv  .hash
gnu   .gnu.hash
both  .gnu.hash .hash
</pre>
                </div>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Both tables do the same job and both use the same hash function. They differ in how much they store and therefore in what a lookup costs.</p>
                <div class="hex-dump">
                    <pre>  THE HASH (identical in both, and reused a third time
  in .gnu.version_d -- see the Versioned Symbols concept)

      h = 0
      for each byte c of the name:
          h = (h &lt;&lt; 4) + c
          g = h &amp; 0xf0000000
          if g: h ^= g &gt;&gt; 24
          h &amp;= ~g
      return h

  .hash (SysV)        .gnu.hash
  ------------        ----------
  nbucket, nchain     nbuckets, symoffset,
  bucket[]            bloom_size, bloom_shift
  chain[]             bloom[]
                      bucket[]
                      chain[]
</pre>
                </div>
                <p><strong>The same function in three unrelated tables</strong> &mdash; <code>.hash</code>, <code>.gnu.hash</code>, and the version-definition name hash &mdash; is one of those accidents that turns out to be load-bearing. It means a loader can compare a 32-bit number instead of a string when matching a version requirement, and it means the two hash tables agree about which symbols collide, so a name that lands in the same bucket in one lands in the same bucket in the other.</p>
                <p>The structural difference is the interesting part. <code>.hash</code> stores an entry for <em>every</em> exported symbol, including the ones nobody will ever look up. <code>.gnu.hash</code> stores nothing per symbol except one chain word, plus a Bloom filter in front to reject most misses without touching the chain at all. <strong>That is the entire optimisation: a lookup that misses should not have to read a symbol table entry to find out it missed.</strong></p>
            </div>

            <div class="unit unit-reality">
                <h2>Does It Actually Work?</h2>
                <p>Decode <code>.gnu.hash</code> from a real binary and check the structure:</p>
                <div class="hex-dump">
                    <pre>$ python3 symtables.py /bin/ls
-- .gnu.hash --
    nbuckets=3 symoffset=268 bloom_size=1 bloom_shift=6
    bloom words: 0x3819400128c10084
    buckets    : [268, 272, 275]
    5 invariants hold, 0 broken
    MEASURED: 268 of 268 adjacent bucket pairs are out of index order
</pre>
                </div>
                <p><strong>That last line is Finding 20, and it is the surprise in this concept.</strong> With three buckets and <code>symoffset = 268</code> the heads look sorted, which is what makes the false intuition so easy to form. Now try a real library:</p>
                <div class="hex-dump">
                    <pre>$ python3 symtables.py /lib/x86_64-linux-gnu/libc.so.6 | grep -A6 'gnu.hash --'
    nbuckets=1017 symoffset=262
    buckets    : [2620, 977, 267, 1613, 568, 3084, ...]
</pre>
                </div>
                <p>Bucket 0&rsquo;s head is <strong>2620</strong>. Bucket 1&rsquo;s head is <strong>977</strong>. The heads are wildly out of index order, and this is normal, not corruption.</p>
                <p>The reason is worth stating precisely, because it is the thing the intuition gets wrong. <strong>Each bucket is a <em>contiguous run</em> of adjacent <code>.dynsym</code> indices &mdash; that part is true, and it is why the walk is just <code>i, i+1, i+2, ...</code> until a chain word with its low bit set. But the runs are laid out one after another <em>in bucket order</em>, and bucket order is hash order, not index order.</strong> The two orderings coincide only when the number of buckets is small enough that the sortedness is an accident.</p>
                <p>Now the <code>.hash</code> verification, which is the one that can be checked completely. Rebuild every symbol&rsquo;s bucket from the hash and walk the chains:</p>
                <div class="hex-dump">
                    <pre>$ python3 symtables.py /lib/x86_64-linux-gnu/libc.so.6 | grep -A3 'hash (SysV)'
    nbucket=1017 nchain=3189
    3188 symbols consistent, 0 inconsistent
</pre>
                </div>
                <p><strong>3188 of 3188.</strong> Every exported symbol in glibc lands in exactly the bucket <code>elf_hash(name) % 1017</code> predicts, with <code>@version</code> stripped from the name first. That last part is the detail that makes versioning work at all, and it is the next concept.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Why the hash is computed over the <em>base</em> name, stripped of its version. glibc exports the same function under two version names, and the loader has to find the right one:</p>
                <div class="hex-dump">
                    <pre>$ readelf --dyn-syms -W /lib/x86_64-linux-gnu/libc.so.6 | grep -E ' (abort|bcopy)@'
   132: ... FUNC GLOBAL DEFAULT UND abort@GLIBC_2.2.5 (5)
   185: ... FUNC GLOBAL DEFAULT UND bcopy@GLIBC_2.2.5 (5)
</pre>
                </div>
                <p>In a library that <em>defines</em> versioned symbols, one base name has several versioned entries. The hash is over <code>printf</code>, not <code>printf@@GLIBC_2.2.5</code> &mdash; and that is not a simplification, it is the design. <strong>All versions of one name share a single chain.</strong> The lookup walks the chain comparing the base name, and only <em>after</em> it has a match does it check the version index.</p>
                <p>The alternative would be one chain per <em>versioned</em> name, which would mean the loader had to know the version before it could hash anything &mdash; and the version is a property of the <em>reference</em>, not of the definition. A reference to <code>printf@@GLIBC_2.2.5</code> and a reference to <code>printf@@GLIBC_2.38</code> must both be able to find the same chain and then differ on the version check. Stripping first is what makes that possible with one structure.</p>
                <p>The cost is that the chains are longer than they need to be, and the loader does a version comparison for every candidate it walks past. For a name with a dozen historical versions that is a dozen comparisons on a hit. <strong>Correct and slightly wasteful, chosen once, twenty-five years ago, and still the right trade</strong> &mdash; because the alternative is not slightly wasteful, it is structurally impossible.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Try It Yourself</h2>
                <div class="hex-dump">
                    <pre>$ cd courses/sym/assets/samples
$ ./build_samples.sh 2&gt;&amp;1 | sed -n '/Finding 18/,/Findings 11/p'
$ python3 symtables.py /bin/ls | sed -n '/gnu.hash --/,$p'
$ python3 symtables.py /lib/x86_64-linux-gnu/libc.so.6 | grep -A3 'SysV'
</pre>
                </div>
                <p>Then check the invariants yourself, and try to break Finding 20:</p>
                <div class="hex-dump">
                    <pre>  1. symtables.py checks five structural invariants of
     .gnu.hash. Name them, and say which one is the reason
     a lookup is O(1) rather than O(chain).

  2. For each of these, is the bloom filter useful?
       a binary with 4 exported symbols
       a library with 3000
       a binary that looks up 1 name and exits

  3. The out-of-order heads: find the SMALLEST library on
     this machine where buckets[0] > buckets[1]. Why is
     there a threshold below which you never notice?

  4. symoffset=268 in /bin/ls and 262 in libc. What are
     entries 0..symoffset-1, and why must they be excluded
     from the hash?
</pre>
                </div>
                <p>Question 4 has the answer that ties this concept to the previous module: the entries below <code>symoffset</code> are the ones with no business being found by name &mdash; undefined symbols, mostly, plus the bookkeeping entries. <strong>Undefined symbols are the demands the static linker failed to satisfy, and the loader is their last chance.</strong> They are deliberately outside the lookup table because a lookup that could only return an undefined symbol would be a lookup that cannot fail, and the loader needs it to be able to fail.</p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>This opens the runtime module, and the reason the module exists is the gap this concept sits in. <a href="/courses/sym/lessons/sym-algorithm">The Algorithm, Measured</a> gave a linker that sees every file at once and can therefore afford a linear pass. <strong>The loader sees a set of libraries that did not exist at link time, so it needs an index, and that index is what this concept decoded.</strong> The whole module is one question asked twice: <em>which definition of this name?</em> &mdash; once by <code>ld</code> against every file, once by <code>ld.so</code> against a hash table of whatever got mapped.</p>
                <p>Within the module the chain is direct. This concept builds the index; <a href="/courses/sym/lessons/sym-plt">The PLT and the GOT</a> is how a call site reaches that index, and reading those six instructions is much easier once you know what is on the other end of the jump. <a href="/courses/sym/lessons/sym-binding-time">Lazy, Eager, and the Flag That Does Nothing</a> is about <em>when</em> the index is consulted, and the experiment in that concept only works because this one established that the index is a data structure rather than a scan. <a href="/courses/sym/lessons/sym-copy-reloc">Who Owns the Storage</a> is the case where the loader&rsquo;s answer has to disagree with the linker&rsquo;s.</p>
                <p>The versioning connection is the strongest in the course and it is a direct consequence of the base-name rule. Because the hash strips <code>@version</code>, <strong>one chain holds every version of a name</strong>, and the second half of a versioned lookup is a comparison against <code>.gnu.version</code> rather than a second table walk. <a href="/courses/sym/lessons/sym-version">Versioned Symbols</a> is where that comparison happens, and it reuses the <em>same hash function</em> for a third purpose &mdash; which is why Finding 12 there is really a continuation of this concept rather than a separate fact.</p>
                <p>One connection outside the course, because it is a design lesson rather than a mechanism. <strong>This is the only place in a program where a data structure is chosen for a workload that is 99% misses.</strong> Symbol lookup is overwhelmingly a miss &mdash; most names in a table are never looked up, and most lookups are for names that resolve immediately. The SysV design optimises for build time (one word per symbol, no build cost). The GNU design optimises for the miss. <strong>Both are shipped, because &ldquo;which is better&rdquo; depends on how many libraries are loaded, and that changed from one to ten over the lifetime of the format.</strong> That is a recurring pattern: an ABI outlives the workload it was designed for, so it keeps both answers and lets a flag choose.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/sym/lessons/sym-duplicate">Previous: Two Definitions and One Tentative</a></span>
                <span>Next: <a href="/courses/sym/lessons/sym-plt">The PLT and the GOT</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
