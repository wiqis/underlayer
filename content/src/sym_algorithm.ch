// Symbol Resolution and Symbol Tables — Module 2: The Resolution Algorithm
// Concept: what a linker actually does, left to right, driven by demand.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_sym_algorithm() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Algorithm, Measured — Underlayer")
    page.appendTitle(&title)

    render_lesson_nav(&mut page)
    render_lesson_css(&mut page)

    #html {
        <div class="lesson sym-lesson">
            <a href="/courses/sym" class="back-link">Back to course</a>
            <h1>The Algorithm, Measured</h1>
            <div class="lesson-meta">22 min &middot; Module 2: The Resolution Algorithm &middot; Intermediate</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Linking is usually described as &ldquo;matching up symbols&rdquo;, which is true and completely useless, because it does not tell you what happens when the match is not unique, not found, or not needed. Here is a link that fails for a reason no amount of symbol-matching intuition predicts:</p>
                <div class="hex-dump">
                    <pre>$ cat mu.c
extern int a_fn(void);
int main(void) { return a_fn(); }
$ cat ma.c
extern int b_data;
int a_fn(void) { return 1 + b_data; }
$ cat da.c
int a_data = 10;
$ cat mb.c
extern int a_data;
int b_fn(void) { return 2 + a_data; }
$ cat db.c
int b_data = 20;

$ ar rcs libMA.a ma.o da.o
$ ar rcs libMB.a mb.o db.o

$ clang -o prog mu.o libMA.a libMB.a
$ ./prog ; echo $?
21                        &lt;-- fine

$ clang -o prog mu.o libMB.a libMA.a
ma.c:(.text+0x7): undefined reference to `b_data'
</pre>
                </div>
                <p><strong>The same four object files, in a different order, and one order links while the other does not.</strong> Every symbol involved is defined exactly once. There is no duplicate, no missing definition, no ambiguity. The failure is purely about <em>sequence</em>, and the message names <code>b_data</code> &mdash; a symbol that <em>is</em> defined, in <code>db.o</code>, inside an archive that was on the command line.</p>
                <p>Understanding why is the entire content of this module.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>GNU ld&rsquo;s static link is a single left-to-right pass with one piece of state: <strong>the set of currently-undefined symbols</strong>. It starts with everything undefined, and shrinks.</p>
                <div class="hex-dump">
                    <pre>  THE PASS

  undefined = {}                      # nothing wanted yet

  for each input file F, left to right:
      if F is an OBJECT (.o):
          add every symbol F defines to `defined`
          remove every symbol F references from `undefined`
      if F is an ARCHIVE (.a):
          repeat:
              pulled = false
              for each MEMBER M of F, in archive order:
                  if M defines something still in `undefined`:
                      take M:  add its definitions to `defined`
                                 remove its references from `undefined`
                      pulled = true
              until nothing more can be pulled
      if F is a SHARED OBJECT (.so):
          record it as a source of definitions, but resolve nothing yet

  at the end: anything left in `undefined` is an error
</pre>
                </div>
                <p>Three consequences fall straight out of that pseudocode, and each one is a thing people get wrong.</p>
                <p><strong>One: an object file is unconditional, an archive is conditional.</strong> Everything in a <code>.o</code> is always taken, whether it is needed or not. A member of an <code>.a</code> is taken <em>only</em> if it answers a name that is undefined <em>at that moment</em>. This is the entire reason archives exist: they let you ship a thousand-object library and link only the eight objects your program needs.</p>
                <p><strong>Two: the scan is one pass, not repeated.</strong> The inner <code>repeat</code> loop is within a single archive, and it is what makes an archive self-contained. It is <em>not</em> a retry of earlier archives. Once the linker has moved past <code>libMB.a</code>, it does not come back.</p>
                <p><strong>Three: therefore order is a semantic input.</strong> Not a performance hint, not a style preference &mdash; part of the meaning of the link. <code>libMA.a libMB.a</code> and <code>libMB.a libMA.a</code> are different links, and in general only one of them resolves.</p>
            </div>

            <div class="unit unit-reality">
                <h2>Does It Actually Work?</h2>
                <p>Step through the failing order by hand. Start: <code>mu.o</code> wants <code>a_fn</code>.</p>
                <div class="hex-dump">
                    <pre>  ORDER: mu.o  libMB.a  libMA.a

  mu.o      defines: main
            wants:    a_fn                undefined = { a_fn }

  libMB.a   scan members for anything defining a_fn:
              mb.o  defines b_fn, a_data   no
              db.o  defines b_data         no
            nothing pulled                undefined = { a_fn }

  libMA.a   scan members:
              ma.o  defines a_fn          YES  -> take it
                    wants b_data           undefined = { b_data }
              (repeat within this archive)
              da.o  defines a_data        b_data is not a_data. no.
            undefined = { b_data }         &lt;-- never satisfiable now

  END       b_data was defined, in db.o, 30 lines of output ago.
            The linker is not allowed to look back. ERROR.
</pre>
                </div>
                <p>And the working order, for contrast:</p>
                <div class="hex-dump">
                    <pre>  ORDER: mu.o  libMA.a  libMB.a

  mu.o      wants a_fn                undefined = { a_fn }
  libMA.a   ma.o defines a_fn         -> take;  wants b_data
                                           undefined = { b_data }
            da.o defines a_data        not b_data. stop.
  libMB.a   mb.o defines b_fn         not b_data. no.
            db.o defines b_data        YES -> take
            undefined = { }             done
</pre>
                </div>
                <p><strong>Notice what the second trace does that the first cannot: the demand for <code>b_data</code> is created <em>inside</em> <code>libMA.a</code>, and <code>libMB.a</code> has not been passed yet.</strong> That is the entire mechanism. A demand can only be satisfied by something to its right.</p>
                <p>Now the question the map file answers, which is more interesting than whether the link succeeded &mdash; <strong>which member was actually read?</strong></p>
                <div class="hex-dump">
                    <pre>$ clang -o prog mu.o -Wl,--start-group libMB.a libMA.a -Wl,--end-group \
        -Wl,-Map=prog.map
$ grep -E '^libM[AB]\.a\(' prog.map
libMA.a(ma.o)      mu.o            (a_fn)
libMB.a(db.o)      libMA.a(ma.o)   (b_data)
</pre>
                </div>
                <p>Two members, not three. <code>libMB.a(mb.o)</code> is <strong>absent from the map entirely</strong> &mdash; it defines <code>b_fn</code>, which nothing ever wanted, so it was never read off the archive. <code>da.o</code> is there because it came along inside the same archive as the member that was pulled; archive granularity is per-file, not per-symbol.</p>
                <p><strong>This is worth stating as a performance fact, not just a curiosity: an unused archive member costs nothing, not even a read.</strong> The index at the front of the archive is what makes that possible, and it is the structure the object-files course measured in <code>.a</code> files. The linker consults a table of names to offsets, decides that <code>mb.o</code> is not in it, and moves on.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>The mutual-dependency case is not a toy, because it is what happens when two independently-maintained libraries each grow a dependency on the other. And <code>--start-group</code> exists precisely for it:</p>
                <div class="hex-dump">
                    <pre>$ clang -o prog mu.o -Wl,--start-group libMB.a libMA.a -Wl,--end-group
$ ./prog ; echo $?
21                        &lt;-- links, in EITHER order
</pre>
                </div>
                <p><code>--start-group</code> / <code>--end-group</code> turns the archives inside into a <strong>fixed-point region</strong>: keep cycling through the group, pulling whatever answers a pending demand, until a whole pass pulls nothing. That is the whole feature, and the next concept is about it properly.</p>
                <p>There is a cost, and it is worth knowing when to reach for the flag versus when to fix the build. The group is rescanned until it stabilises, so a group of <em>n</em> archives with heavy interdependency can take several passes, and each pass re-reads the archive indexes. <strong>The reflex fix &mdash; wrap everything in <code>--start-group</code> &mdash; is usually wrong</strong>, because it also removes the signal that your libraries have a dependency cycle you should probably break. Build systems that do it by default tend to get slower over time for no visible benefit.</p>
                <p>The other real-world case is <code>--as-needed</code>, which is the same algorithm pointed the other way. By default a <code>.so</code> on the command line is recorded as a dependency whether or not it answered anything. <code>--as-needed</code> drops it if it did not, which is why a library can stop appearing in <code>ldd</code> output after you add a flag that has nothing to do with linking libraries. <strong>Same demand-driven idea, different question: not &ldquo;which members do I need&rdquo; but &ldquo;which whole libraries did I actually use&rdquo;.</strong></p>
            </div>

            <div class="unit unit-apply">
                <h2>Try It Yourself</h2>
                <div class="hex-dump">
                    <pre>$ cd courses/sym/assets/samples
$ ./build_samples.sh 2&gt;&amp;1 | sed -n '/Finding 6/,/Finding 7/p'
$ python3 crosscheck.py 2&gt;&amp;1 | sed -n '/\[4\]/,/^$/p'
</pre>
                </div>
                <p>Then build the trace yourself. Put the archives in the order that fails, and answer from the algorithm rather than by experiment:</p>
                <div class="hex-dump">
                    <pre>  1. libMA.a = (ma.o, da.o),  libMB.a = (mb.o, db.o)
     ma.o defines a_fn, wants b_data
     mb.o defines b_fn, wants a_data
     da.o defines a_data
     db.o defines b_data

     Without running anything: which members are pulled, and in
     what order, for each of the four orderings below?

       mu.o libMA.a libMB.a
       mu.o libMB.a libMA.a
       mu.o libMA.a libMB.a libMA.a     (listed twice)
       mu.o libMB.a libMA.a libMB.a     (listed twice)

  2. Question 1's third and fourth lines have a duplicate. Why
     is the SECOND mention of libMA.a enough to pull da.o in
     case 3, when in case 1 it was not pulled at all?
</pre>
                </div>
                <p>Question 2 is the one that teaches the algorithm. In case 1, by the time the pass reaches the end, nothing is undefined, so a second visit to <code>libMA.a</code> would find no demand. In case 3, the second <code>libMA.a</code> comes <em>after</em> <code>libMB.a</code>, and by then <code>da.o</code> may be wanted. <strong>The fixpoint is not &ldquo;try harder&rdquo; &mdash; it is that position in the sequence is what carries meaning.</strong></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p><a href="/courses/sym/lessons/sym-order">Order, Archives and the Map File</a> is this concept applied: same algorithm, but the consequences pulled apart &mdash; the map file as an observation tool, <code>--start-group</code> as the sanctioned escape, and the cost of reaching for it. Read them in that order and the two lessons are one argument split for length.</p>
                <p>Back to the identity module, the algorithm is what gives binding and visibility their teeth. <a href="/courses/sym/lessons/sym-binding">Binding, and the Two Tables</a> established that a <code>LOCAL</code> name is invisible outside its file and a <code>WEAK</code> definition may lose; this concept is where &ldquo;may lose&rdquo; becomes the rule that equal candidates are decided by position. <a href="/courses/sym/lessons/sym-visibility">Visibility Is Not Binding</a> contributed the <em>candidate set</em> &mdash; a <code>LOCAL</code> symbol is not a candidate at all, and a <code>PROTECTED</code> one is a candidate that cannot be beaten later.</p>
                <p>Forward, and this is the connection that makes the module matter: <strong>every line of this pseudocode is about the static case, and not one of them applies to a shared object.</strong> A <code>.so</code> resolves nothing at link time, because the set of libraries that will be loaded is not known until run time. The whole runtime module exists because of that gap. <a href="/courses/sym/lessons/sym-hash">Two Hash Tables, One Job</a> is the data structure the loader uses to answer the same question against the same kind of table; <a href="/courses/sym/lessons/sym-plt">The PLT and the GOT</a> is the mechanism by which it defers the question; <a href="/courses/sym/lessons/sym-binding-time">Lazy, Eager, and the Flag That Does Nothing</a> is about exactly when the answer is demanded; and <a href="/courses/sym/lessons/sym-copy-reloc">Who Owns the Storage</a> is the case where the linker&rsquo;s answer and the loader&rsquo;s answer have to be reconciled, and cannot always be.</p>
                <p>Finally, the connection to the object files course is mechanical and worth stating because it closes a loop. <a href="/courses/obj/lessons/obj-archives">The Archive</a> measured the <code>.a</code> format &mdash; the index, the members, the header &mdash; and noted that GNU ld&rsquo;s resolution is a fixed-point iteration rather than a backwards scan. <strong>This concept is that other half: the index is what makes the demand-driven scan cheap, and the fixed point is why the scan can defeat itself when the order is wrong.</strong></p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/sym/lessons/sym-visibility">Previous: Visibility Is Not Binding</a></span>
                <span>Next: <a href="/courses/sym/lessons/sym-order">Order, Archives and the Map File</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
