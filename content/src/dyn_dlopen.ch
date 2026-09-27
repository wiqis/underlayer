// Dynamic Linking and Shared Libraries — Module 3: Loading at Run Time
// Concept: loading a library when the program does not know it exists, and the
// mode bit that catches everybody.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_dyn_dlopen() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("dlopen, dlsym, and the Mode Bits — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson dyn-lesson">
            <a href="/courses/dyn" class="back-link">Back to course</a>
            <h1>dlopen, dlsym, and the Mode Bits</h1>
            <div class="lesson-meta">23 min &middot; Module 3: Loading at Run Time &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Everything so far in this course has assumed the libraries are in <code>DT_NEEDED</code>. That is a link-time decision, written into the file. <code>dlopen</code> is the one mechanism that adds to the scope <em>after</em> the program has started &mdash; and it is how plugins, drivers, and graphics backends have always worked.</p>
                <div class="hex-dump">
                    <pre>$ cat dl.c
#include &lt;dlfcn.h&gt;
#include &lt;stdio.h&gt;
int main(int argc, char **argv){
  int bind  = (argc &gt; 2 &amp;&amp; argv[2][0]=='n') ? RTLD_NOW : RTLD_LAZY;
  int scope = (argc &gt; 1 &amp;&amp; argv[1][0]=='g') ? RTLD_GLOBAL : RTLD_LOCAL;
  void *h = dlopen("./libplug.so", bind | scope);
  if(!h){ printf("  FAILED: %s\n", dlerror()); return 1; }
  int (*pv)(void) = (int(*)(void))dlsym(h, "plug_value");
  printf("  mode=%-6s plug_value()=%d  dlsym(\"nope\")=%p\n",
         (scope &amp; RTLD_GLOBAL) ? "GLOBAL" : "LOCAL", pv(), dlsym(h,"nope"));
  dlclose(h);
  return 0;
}
$ clang -o dlprog dl.c -ldl
$ ./dlprog local
  mode=LOCAL  plug_value()=55  dlsym("nope")=(nil)
$ ./dlprog global
  mode=GLOBAL plug_value()=55  dlsym("nope")=(nil)
</pre>
                </div>
                <p>Both work, both give 55, and a missing symbol gives <code>NULL</code> rather than a crash. <strong>The program never mentions <code>libplug.so</code> in its link line and the loader never sees it in <code>DT_NEEDED</code> &mdash; it arrives because the program asked for it by path.</strong></p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>What the handle is, and what the flags actually do. The handle is the concept and it is not obvious.</p>
                <div class="formula">
  dlopen(path, mode)  -&gt;  a HANDLE

  a handle is NOT the library's address. it is an index
  into the loader's private list of loaded objects --
  a token meaning "this one, specifically".

  WHY IT MATTERS: it is the argument to dlsym, and
  dlsym(h, name) searches ONLY that object's .dynsym.

  dlsym(RTLD_DEFAULT, name)   search the GLOBAL scope
  dlsym(RTLD_NEXT,    name)   start the global search
                              AFTER the object that is
                              asking. used by
                              LD_PRELOAD libraries to
                              find the one they replaced.

  RTLD_NEXT is the one everybody meets in anger, and
  the interposition concept already used it. it is a
  RELATIVE question: "the next one after me", which
  only makes sense because the loader knows which
  object is calling.

                </div>
                <p>And the mode bits, which are two independent axes in one integer:</p>
                <div class="formula">
  THE BINDING AXIS -- WHEN is the symbol resolved?
    RTLD_LAZY   on the first call through the PLT
    RTLD_NOW    now, for every symbol, and fail the
                dlopen if any is missing

  THE SCOPE AXIS -- does it join the global list?
    RTLD_LOCAL   default. reachable only through the
                 handle you got back.
    RTLD_GLOBAL  reachable to every later lookup,
                 including by code that was already
                 loaded and knows nothing about it.

  MEASURED VALUES:
    RTLD_LOCAL  0x0      RTLD_GLOBAL 0x100
    RTLD_LAZY   0x1      RTLD_NOW    0x2

                </div>
                <p><strong>Which is where the trap lives, and it is a good one.</strong> <code>RTLD_LOCAL</code> is <em>zero</em>. So:</p>
                <div class="hex-dump">
                    <pre>  dlopen("./libplug.so", 0)
  -&gt; ./libplug.so: invalid mode for dlopen(): Invalid argument

  "invalid mode" is a confusing message, because the
  mode LOOKS like it was supplied. it was: RTLD_LOCAL,
  which is 0, and 0 contains neither RTLD_LAZY nor
  RTLD_NOW, and the loader requires one of them.

  the correct form is a disjunction of both axes:
      dlopen(path, RTLD_LAZY | RTLD_LOCAL)
      dlopen(path, RTLD_NOW  | RTLD_GLOBAL)

  and RTLD_NOW is the one that fails loudly: if any
  symbol the library needs is missing, dlopen returns
  NULL and dlerror() explains. RTLD_LAZY will happily
  load a library that cannot possibly work and tell you
  at the first call instead.
</pre>
                </div>
            </div>

            <div class="unit unit-reality">
                <h2>Does It Actually Work?</h2>
                <p>First, the thing that makes <code>dlopen</code> different from everything else in the course:</p>
                <div class="hex-dump">
                    <pre>$ readelf -dW dlprog | sed -n 's/.*(NEEDED).*\[\(.*\)\]/  NEEDED \1/p'
  NEEDED libc.so.6

$ readelf -lW dlprog | grep INTERP | sed 's/^ */  /'
  INTERP  0x000374 ... [ /lib64/ld-linux-x86-64.so.2 ]
</pre>
                </div>
                <p><strong><code>libplug.so</code> is not in <code>DT_NEEDED</code> and never was.</strong> The file records one dependency, and the library is reached through a string in the program&rsquo;s data. <strong>That is the whole reason for the mechanism</strong>: the dependency is not known when the binary is written, which is exactly the situation for a plugin, a driver chosen by configuration, or anything selected by a user.</p>
                <p>Now the two scope flags, tested for the thing that actually differs between them &mdash; whether a symbol becomes visible to code that was already loaded. Note the second <code>dlsym</code> below: it asks a <em>global</em> question, not a handle question.</p>
                <div class="hex-dump">
                    <pre>$ cat late2.c
#include &lt;dlfcn.h&gt;
#include &lt;stdio.h&gt;
#include &lt;stdlib.h&gt;
int main(void){
  void *h = dlopen("./libplug.so",
                   (getenv("G") ? RTLD_GLOBAL : RTLD_LOCAL) | RTLD_LAZY);
  if(!h){ printf("  dlopen: %s\n", dlerror()); return 1; }
  int (*hk)(void) = (int(*)(void))dlsym(RTLD_DEFAULT, "hook");
  printf("  RTLD_DEFAULT finds hook(): %s\n", hk ? "yes" : "NO");
  return 0;
}
$ clang -o late2 late2.c -ldl -Wl,-rpath,'$ORIGIN'
$ ./late2
  RTLD_DEFAULT finds hook(): NO
$ G=1 ./late2
  RTLD_DEFAULT finds hook(): yes
</pre>
                </div>
                <p><strong>That is the difference, and it is exactly what the flag name says.</strong> <code>RTLD_LOCAL</code>: reachable only through the handle you were given. <code>RTLD_GLOBAL</code>: reachable to every later global lookup, including from code that was already loaded and knows nothing about this library. <strong>And the second <code>dlsym</code> is a different question from the first</strong> &mdash; <code>dlsym(h, ...)</code> asks about one object and always works; <code>dlsym(RTLD_DEFAULT, ...)</code> asks about the whole scope and is what the flag changes. Confusing those two is the second most common <code>dlopen</code> mistake after the mode bits.</p>
                <p>And two more facts that are not in the documentation, both measured:</p>
                <div class="hex-dump">
                    <pre>$ cat twice.c
  void *a = dlopen("./libplug.so", RTLD_LAZY|RTLD_LOCAL);
  void *b = dlopen("./libplug.so", RTLD_LAZY|RTLD_LOCAL);
  printf("  same handle: %s   ", a==b ? "YES" : "no");
  dlclose(a);
  printf("after dlclose(a), handle b still works: %s\n", ...);

$ ./twice
  same handle: YES   after dlclose(a), handle b still works: yes
</pre>
                </div>
                <p><strong><code>dlopen</code> on an already-loaded library does not load it again.</strong> It increments a reference count and hands back the same object, so the two handles are equal, and <code>dlclose</code> on one of them does not invalidate the other. This matters more than it looks: a plugin host that caches a handle and a caller that <code>dlclose</code>&rsquo;s its own copy will find the library still resident and the handle still valid, and a host that assumed otherwise would be adding a lifetime bug to every caller.</p>
                <p>And the reason <code>RTLD_NOW</code> exists, which is a failure rather than a feature:</p>
                <div class="hex-dump">
                    <pre>$ printf 'extern int nonexistent_thing(void);\nint bad(void){ return nonexistent_thing(); }\n' &gt; bad.c
$ clang -fPIC -shared -o libbad.so bad.c
$ cat dbad.c        /* dlopen, then report */
  void *h = dlopen("./libbad.so", mode);
  printf("  %-4s : %s\n", ..., h ? "dlopen SUCCEEDED" : dlerror());

$ ./dbad
  lazy : dlopen SUCCEEDED
$ ./dbad now
  now  : ./libbad.so: undefined symbol: nonexistent_thing
</pre>
                </div>
                <p><strong><code>RTLD_LAZY</code> loads a library that can never work.</strong> The unresolved reference is discovered at the first call into it &mdash; which may be much later, on a different code path, or never. <code>RTLD_NOW</code> resolves everything up front and fails the <code>dlopen</code> with a message naming the symbol. <strong>For a plugin, whose whole purpose is to be loaded because the user asked for it, that is the difference between a message and a mystery.</strong></p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>What a plugin system actually looks like, and why it is written the way it is. Every piece is one of the mechanisms on this page.</p>
                <div class="hex-dump">
                    <pre>  /* the whole of a plugin loader */
  void *h = dlopen(path, RTLD_NOW | RTLD_LOCAL);
  if (!h) { log("dlopen: %s", dlerror()); return -1; }
  init_fn init = (init_fn)dlsym(h, "plugin_init");
  if (!init) { log("no plugin_init: %s", dlerror()); return -1; }
  return init(handle);

  FOUR DECISIONS, each one a lesson from this page:

  RTLD_NOW    the plugin is loaded because the user asked
              for it, and a failure now is a message. lazy
              would defer a missing symbol to a call that may
              be in a hot loop.

  RTLD_LOCAL  a plugin's symbols should not join the global
              scope. otherwise plugin A's malloc can be
              interposed by plugin B, loaded later, and the
              program's behaviour depends on load order.

  dlsym(h,..) not RTLD_DEFAULT. the handle is the only
              thing that identifies THIS plugin. a global
              lookup would find whichever plugin loaded first.

  dlerror()   after EVERY dlsym. a NULL return is
              ambiguous -- missing symbol, or a real symbol
              whose value is NULL -- and dlerror is the only
              way to tell.
</pre>
                </div>
                <p><strong>Every one of those four is a bug somebody shipped first.</strong> <code>RTLD_GLOBAL</code> because it seemed more capable, and the consequence is that two plugins that both wrap <code>malloc</code> break each other in an order-dependent way. <code>dlsym(RTLD_DEFAULT, ...)</code> because it was shorter, and the consequence is that the second plugin loaded gets the first plugin&rsquo;s symbol.</p>
                <p>And the failure mode worth naming, because it is invisible until it is catastrophic: <strong>symbol collision between plugins.</strong></p>
                <div class="hex-dump">
                    <pre>  two plugins both export `compute'. both are
  dlopen'd with RTLD_LOCAL. both dlsym their own handle,
  both get their own function, and both work perfectly.

  now one of them is rebuilt with -fvisibility=hidden
  and forgets to mark `compute' default. its dlsym
  returns NULL. the plugin reports "not a valid plugin"
  and the user sees a feature that stopped working after
  a dependency bump.

  the previous concept predicted this exactly: -fvisibility=
  hidden removes the name from .dynsym, and dlsym searches
  .dynsym. the flag that makes a library tidy also makes it
  unloadable by name.
</pre>
                </div>
                <p><strong>Visibility, the export list, and <code>dlopen</code> are the same subject seen from three sides.</strong> A symbol hidden to keep a library&rsquo;s internals private is a symbol a plugin host cannot find &mdash; and the diagnostic a user sees will never mention visibility.</p>
                <p>One more measured fact, because it is the one that surprises people who assume <code>dlclose</code> does what it says:</p>
                <div class="hex-dump">
                    <pre>  dlclose(h) drops a reference count. whether the
  object is actually UNMAPPED depends on whether anything
  else still needs it -- and on this glibc, a library that
  registered TLS, has unique symbols, or is still the
  target of a live PLT slot commonly stays resident.

  so "dlclose unloads the library" is NOT a claim this
  course makes. what dlclose guarantees is that the HANDLE
  stops being usable and the reference count drops. what
  the loader does afterwards is an implementation choice
  with a long list of reasons to be conservative.
</pre>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Try It Yourself</h2>
                <div class="hex-dump">
                    <pre>$ cd courses/dyn/assets/samples
$ ./build_samples.sh 2&gt;&amp;2 | sed -n '/D6/,/D7/p'
$ python3 crosscheck.py 2&gt;&amp;2 | sed -n '/\\[6\\]/,/\\[7\\]/p'
$ python3 dynscope.py exports libplug.so
</pre>
                </div>
                <p>Then build a loader, because the failures are the lesson:</p>
                <div class="hex-dump">
                    <pre>  1. dlopen with each of: 0, RTLD_LOCAL,
     RTLD_LAZY, RTLD_LAZY|RTLD_LOCAL, RTLD_NOW|RTLD_GLOBAL.
     Which fail, and what is dlerror() for each? (Four of
     five work. The one that fails is the one that LOOKS
     like it supplied a mode.)

  2. dlopen the SAME library twice and compare the
     handles. Same or different? Now dlclose once and
     dlsym again. (The handle stays valid -- there is a
     reference count, and this is the rule nobody
     documents.)

  3. dlsym(RTLD_DEFAULT, "plug_value") after an RTLD_LOCAL
     dlopen. Then after an RTLD_GLOBAL one. (This is the
     difference between the two flags, and it is the only
     observable one.)

  4. RTLD_NOW a library that references a symbol nobody
     defines. Does dlopen fail? Then the same with
     RTLD_LAZY -- does it succeed? If it does, when do
     you find out? (This is why the example uses NOW.)

  5. Rebuild libplug.so with -fvisibility=hidden and
     forget to mark plug_value. dlsym returns NULL and
     dlerror says "undefined symbol". Now make the host
     print dlerror() on failure. The user now sees the
     real reason -- which is the actual fix for every
     dlopen diagnostic ever written badly.

  6. RTLD_NODELETE and RTLD_DEEPBIND: read the manual
     entries and work out which of the four flags from
     this page each one modifies.
</pre>
                </div>
                <p>Exercise 1 is the one worth doing before anything else, and it takes two minutes. <strong>Four of five modes work and the one that fails is the one that looks like it supplied a mode</strong>, because <code>RTLD_LOCAL</code> is zero and zero looks like &ldquo;I did not set a flag&rdquo; rather than &ldquo;I set the default one&rdquo;. Every programmer who writes this API meets it, and the only defence is to have already been burned.</p>
                <p>Exercise 5 is the one that makes the module hang together, because it connects the three concepts of this course into one failure. <strong>A plugin host that does not print <code>dlerror()</code> reports &ldquo;invalid plugin&rdquo;; one that does reports &ldquo;undefined symbol: plug_value&rdquo;.</strong> The bug is in the build flags of the plugin, the symptom is in the loader, and the only place the two can meet is the error message. Every mechanism in this course is invisible without diagnostics, which is a theme worth carrying back through the rest of the collection.</p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>This opens the run-time module. The scope so far has been built once, at load time, from a list in the file. <strong><code>dlopen</code> is the mechanism that extends it after the program has started</strong>, and everything about it follows from that: the library is not in <code>DT_NEEDED</code>, the search path matters more than usual because the name is a string in your data, and a handle is needed because &ldquo;the scope&rdquo; is no longer a thing you can enumerate at compile time.</p>
                <p>The connection to the <a href="/courses/elf/lessons/ld-so">ELF course&rsquo;s loader concept</a> is the completion of its search-path material. That course listed <code>LD_LIBRARY_PATH</code>, <code>DT_RUNPATH</code> and <code>/etc/ld.so.cache</code> and explained how a <code>DT_NEEDED</code> name becomes a path. <strong>All of that machinery is still in play for <code>dlopen</code>, with a difference the earlier course could not show: the name being resolved is a string in your program&rsquo;s data rather than a string in <code>.dynamic</code>.</strong> Which means it can be computed, read from a config file, or typed by a user &mdash; and every one of those turns a build-time decision into a run-time one with a security consequence.</p>
                <p>The second connection is to <a href="/courses/dyn/lessons/dyn-export">Hiding Things, and the Trap</a>, and it is the sharpest practical one in the course. That concept showed <code>-fvisibility=hidden</code> emptying <code>.dynsym</code>, and warned that the failure surfaces at the caller&rsquo;s link step. <strong>For a plugin the failure surfaces at <code>dlsym</code> instead</strong> &mdash; at run time, on the user&rsquo;s machine, for a library built by somebody else. The same mistake, discovered much later and much further from its cause, and the only mitigation is a good <code>dlerror()</code> message.</p>
                <p>And the connection that explains <code>RTLD_NEXT</code>, which the <a href="/courses/dyn/lessons/dyn-interpose">interposition concept</a> used without unpacking. <code>RTLD_NEXT</code> is a <em>relative</em> lookup: start the global search after the object that is asking. <strong>That is only meaningful because the loader knows which object called <code>dlsym</code></strong>, which it knows because it knows the return address on the stack. An <code>LD_PRELOAD</code> library that did not have it would find itself and recurse; that is not a style rule, it is a stack overflow.</p>
                <p>Forward within the module, the two remaining concepts are about the <em>timing</em> of the same decisions rather than their scope. <a href="/courses/dyn/lessons/dyn-bind-time">Lazy, Eager, and What Actually Differs</a> is about <code>RTLD_LAZY</code> versus <code>RTLD_NOW</code> at the <code>dlopen</code> level, and it contains a finding that refines what the <a href="/courses/sym/lessons/sym-binding-time">sym course measured about <code>-z now</code>: no code changes, but <code>.got.plt</code> disappears. <a href="/courses/dyn/lessons/dyn-tls-block">Where the Thread Blocks Come From</a> completes the TLS story the <a href="/courses/reloc/lessons/tls-model">Relocations course</a>&rsquo;s TLS concept</a> started, by looking at the storage the loader has to allocate because no linker could.</p>
                <p>One connection outward, for the security thread that runs through the whole course. <a href="/courses/dyn/lessons/dyn-interpose">The interposition concept</a> showed an attacker winning a name through the search path. <strong><code>dlopen</code> is the same attack with the path chosen by the program rather than by the binary</strong> &mdash; and the mitigations are the ones from that concept plus one more: <code>RTLD_LOCAL</code> stops the loaded library joining the global scope, so a plugin cannot interpose on the program that loaded it. The default is the safe one, which is a rare and slightly suspicious thing to find in an API.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/dyn/lessons/dyn-symbolic">Previous: One Instruction Called -Bsymbolic</a></span>
                <span>Next: <a href="/courses/dyn/lessons/dyn-bind-time">Lazy, Eager, and What Actually Differs</a></span>
            </div>
        </div>
    

    render_lesson_js(&mut page)
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
