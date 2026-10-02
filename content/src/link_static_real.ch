// Static Linking and Linker Scripts — Module 4: Static, and Build One
// Concept: 52x the size, one fewer program header, and an e_type the script
// followed.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_link_static_real() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("What -static Actually Does — Underlayer")
    page.appendTitle(&title)

    render_lesson_nav(&mut page)
    render_lesson_css(&mut page)

    #html {
        <div class="lesson link-lesson">
            <a href="/courses/link" class="back-link">Back to course</a>
            <h1>What -static Actually Does</h1>
            <div class="lesson-meta">20 min &middot; Module 4: Static, and Build One &middot; Intermediate</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>&ldquo;Static linking&rdquo; is three different things wearing one name, and the name is why most explanations of it are unsatisfying. The program to measure is one line:</p>
                <div class="hex-dump">
                    <pre>$ printf 'int main(void){ return 0; }\n' &gt; tiny.c
$ clang -O1          -o s_dyn   tiny.c
$ clang -O1 -static  -o s_static tiny.c
$ for f in s_dyn s_static; do
    printf "  %-9s size=%-8s e_type=%-5s PT_INTERP=%s  PT_LOADs=%s\n" $f \
      "$(stat -c%s $f)" \
      "$(readelf -hW $f|sed -n 's/.*Type: *\([A-Z]*\).*/\1/p')" \
      "$(readelf -lW $f|grep -c INTERP)" \
      "$(readelf -lW $f|grep -c '^  LOAD')"
  done

  s_dyn     size=15880   e_type=DYN   PT_INTERP=1  PT_LOADs=4
  s_static  size=825160  e_type=EXEC  PT_INTERP=0  PT_LOADs=4
</pre>
                </div>
                <p><strong>52 times bigger, and the <code>e_type</code> changed.</strong> Those are the two headline facts and they are not independent &mdash; and the connection between them runs straight through a linker script, which is why this concept is in this course.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Three distinct meanings, and only one of them is usually meant.</p>
                <div class="formula">
  1. STATIC ARCHIVES, DYNAMICALLY LINKED
     ld main.o libfoo.a  -lc
     your code is in the binary; libc is not.
     THIS IS THE DEFAULT and is not what people mean.

  2. STATIC libc
     -static: no .so, no ld.so, one binary.
     the C library's code is IN the file.

  3. FULLY STATIC
     -static plus no PT_INTERP, so there is no
     dynamic loader in the picture at all.
     the kernel maps the file and jumps to e_entry.

  THE DIFFERENCE BETWEEN 2 AND 3 IS A PROGRAM HEADER
  you did not write: PT_INTERP. it names the file to
  load as the interpreter -- /lib64/ld-linux-x86-64.so.2
  on this machine. -static removes it, and that is
  most of what "static" means mechanically.

                </div>
                <p><strong>So the flag does two separable things</strong>: it stops recording references to <code>libc.so</code> and pulling in libc&rsquo;s code, and it stops emitting <code>PT_INTERP</code>. The second is what makes the binary runnable by the kernel alone. A file can be in an odd middle state &mdash; statically linked against libc but still with an interpreter &mdash; and that is worth knowing exists, because it is how you get an error about a missing dynamic loader on a system that obviously has one.</p>
                <div class="formula">
  WHY THE SIZE EXPLODES -- and it is not one thing

  .text   0x08497d  = 543 KB   libc's CODE
  .rodata 0x01c57c  = 116 KB   libc's strings, tables,
                                locale data
  .eh_frame 0x00966c = 38 KB   unwinding tables for all
                                of the above
  .symtab 0x00c210  = 49 KB    symbols for all of it

  vs the dynamic build:
  .symtab 0x000348  = 840 bytes
  .eh_frame under 4 KB

  the dynamic binary has 840 bytes of symbols because
  its code is YOUR code. the static one has 49 KB
  because it now contains a C library.

                </div>
                <p><strong>And here is the link to this course: that <code>.text</code> is at 0x400000 because of a line in the script.</strong></p>
            </div>

            <div class="unit unit-reality">
                <h2>Does It Actually Work?</h2>
                <p>The segments, side by side, and the number that ties the two builds to one file:</p>
                <div class="hex-dump">
                    <pre>$ for f in s_dyn s_static; do
    printf "  %s:\n" $f
    readelf -lW $f | awk '/^  [A-Z]/ {
      t=$1; v=$3; fs=$5; fl=$6; if ($7=="E") fl=fl" E";
      printf "    %-7s vaddr=%-18s filesz=%-9s %s\n", t, v, fs, fl }'
  done

  s_dyn:
    PHDR    vaddr=0x0000000000000040  filesz=0x000310  R
    INTERP  vaddr=0x0000000000000374  filesz=0x00001c  R
    LOAD    vaddr=0x0000000000000000  filesz=0x0005d0  R
    LOAD    vaddr=0x0000000000001000  filesz=0x000141  R E
    LOAD    vaddr=0x0000000000002000  filesz=0x0000f8  R
    LOAD    vaddr=0x0000000000003e00  filesz=0x000210  R W
    DYNAMIC vaddr=0x0000000000003e10  filesz=0x0001b0  R W
    NOTE / GNU_PROPERTY / GNU_EH_FRAME / GNU_STACK / GNU_RELRO

  s_static:
    LOAD    vaddr=0x0000000000400000  filesz=0x000518  R
    LOAD    vaddr=0x0000000000401000  filesz=0x084a8d  R E
    LOAD    vaddr=0x0000000000486000  filesz=0x027f30  R
    LOAD    vaddr=0x00000000004ae108  filesz=0x00b180  R W
</pre>
                </div>
                <p><strong>Three things, and the third is the one that ties the module together.</strong></p>
                <p><strong>One: the dynamic binary has all four <code>PT_LOAD</code>s at addresses near zero</strong> &mdash; 0, 0x1000, 0x2000, 0x3e00. That is because it is <code>ET_DYN</code>: the <em>file</em> records offsets relative to zero and the loader adds the base at run time. <a href="/courses/reloc/lessons/pie-randomize">The Relocations course measured that base moving</a> across runs; this is the same fact seen in the file rather than in a process.</p>
                <p><strong>Two: the static binary is at 0x400000, and that is the script&rsquo;s number.</strong> <code>-static</code> did not choose an address. It changed the <code>e_type</code> to <code>ET_EXEC</code>, and <code>ld</code> laid the image out at the fixed address the default script asks for:</p>
                <div class="hex-dump">
                    <pre>$ grep -n 'SEGMENT_START("text-segment"' default.ld | head -1
13:  . = SEGMENT_START("text-segment", 0x400000) + SIZEOF_HEADERS;

  and the proof that -T moves it, from module 2:
  base=0x800000     first LOAD=0x0000000000800000   ran, exit=0
</pre>
                </div>
                <p><strong>Three: both have four <code>PT_LOAD</code>s.</strong> The size changed by 52&times; and the segment count did not move at all, because the script&rsquo;s very first line says why:</p>
                <div class="hex-dump">
                    <pre>$ head -1 default.ld
/* Script for -z combreloc -z separate-code */
</pre>
                </div>
                <p><strong><code>-z separate-code</code> is why a 52&times;-larger binary has the same number of segments.</strong> It forces the read-only headers, the executable code, the read-only data, and the writable data into four <em>separate</em> mappings, so the loader can apply W^X: code is never in a writable page. It costs a page of address space and one more <code>mmap</code>, and it is on by default. <strong>The default script you have never read is a different script depending on your flags</strong>, and the comment on line 1 is the only place that says so.</p>
                <p>And the honest cost that nobody puts in the man page:</p>
                <div class="hex-dump">
                    <pre>  a static glibc binary does NOT work for:
    - getaddrinfo / NSS  (name resolution needs dlopen
                          of libnss_*.so at RUN TIME)
    - anything using dlopen
    - locales loaded on demand
    - gethostbyname, getpwnam, and friends

  and you find out at RUN TIME, on a machine that has
  every one of those libraries installed, because the
  failure is "cannot open shared object file" from a
  program that does not otherwise use shared objects.
</pre>
                </div>
                <p><strong>This is the real limit of <code>-static</code> on glibc and it is architectural, not a bug.</strong> Name resolution is specified to consult files in <code>/etc</code> at run time; making that work in a static binary requires <code>dlopen</code>, which requires a dynamic loader, which <code>-static</code> just removed. You cannot have both with this C library. The lesson is not &ldquo;static is bad&rdquo; &mdash; it is that a large fraction of &ldquo;static linking&rdquo; is really &ldquo;which dynamic features am I giving up&rdquo;.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Where <code>-static</code> genuinely is the right answer, and what the linker does that is not obvious &mdash; building a static binary <em>with a script that knows about the absence of an interpreter</em>:</p>
                <div class="hex-dump">
                    <pre>  # the eleven-line script, extended for static

  OUTPUT_FORMAT("elf64-x86-64", "elf64-x86-64", "elf64-x86-64")
  OUTPUT_ARCH(i386:x86-64)
  ENTRY(_start)
  SECTIONS
  {
    . = 0x400000 + SIZEOF_HEADERS;
    .text  : { *(.text .stub .text.*) }
    . = ALIGN(0x1000);
    .rodata : { *(.rodata .rodata.*) }
    .data   : { *(.data .data.*) }
    .bss    : { *(.bss .bss.*) }
    /DISCARD/ : { *(.note.GNU-stack) *(.comment) }
  }

  $ clang -O1 -static hello.c -o hi -T mine.ld
  $ ./hi; echo "exit=$?"
  exit=0
  $ readelf -lW hi | grep -c INTERP
  0
</pre>
                </div>
                <p><strong>It works, and the <code>/DISCARD/</code> line is doing real work.</strong> With a script you own, you can drop the section-name comments and the note sections outright, rather than letting the fallback place them. <a href="/courses/link/lessons/link-orphans">The previous concept</a> measured what the fallback does with orphans you did not mention; here you mention everything, so nothing is guessed.</p>
                <p>And the honest comparison of the two ways to build a static binary, which is a decision people actually face:</p>
                <div class="hex-dump">
                    <pre>  -static with the DEFAULT script
    + 0 lines of script to maintain
    + the layout is whatever 800+ people maintain
    -  you cannot change anything
    -  every section the script orphans is placed by
       a table inside the binary

  -static with YOUR script
    + full control, and nothing is guessed
    + you can drop sections, reorder, place absolutely
    -  you own the maintenance, and you will be wrong
       about a section name eventually
    -  -T implies EXEC, which is what you want here but
       is a trap if you forget it (module 2)

  the deciding question is not "which is better" but
  "do I need to change the layout". if no, use the
  default. if yes, you have no option.
</pre>
                </div>
                <p>One more measurement, because it is the honest counterweight to the 52&times; and nobody mentions it. <strong>A static binary is not one binary in practice &mdash; it is one binary <em>per libc</em>.</strong> Linking against glibc statically binds you to that glibc, including its versioned symbol set. Build on a newer distribution, ship the binary, run it on an older one, and the kernel can load it &mdash; and libc&rsquo;s copy of <code>memcpy</code> may not know about a kernel feature the CPU now offers. <strong>That is the cost, and it is a distribution problem rather than a linker problem</strong>, which is why &ldquo;static binaries are portable&rdquo; is true in the sense that matters and false in the sense people usually mean.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Try It Yourself</h2>
                <div class="hex-dump">
                    <pre>$ cd courses/link/assets/samples
$ ./build_samples.sh 2&gt;&amp;2 | sed -n '/F12/,$p'
$ python3 crosscheck.py 2&gt;&amp;2 | sed -n '/\\[12\\]/p'
</pre>
                </div>
                <p>Then measure the thing nobody measures, which is what static actually costs at run time:</p>
                <div class="hex-dump">
                    <pre>  1. Run ldd on both. Then run them under a
     strace that only counts OPENAT. How many files
     does each open before main()? (This is the
     real cost of dynamic linking and it is not the
     size of the binary.)

  2. Compile a program that calls getaddrinfo, once
     -static and once not. Run both. Does the static
     one fail? (If your distro's static glibc has NSS
     built in, it may work -- which is a MORE
     interesting result, and worth finding out which
     you have.)

  3. Now the experiment that ties the module together.
     Build s_static with YOUR script, change the base
     to 0x10000000, and run it. (It works. Then ask
     why -- which line of the script, and which
     concept measured it.)

  4. Build s_static with -Wl,-z,noseparate-code, and
     then check what ld --verbose says its script is.
     How many PT_LOADs now? (TWO, not three -- see
     below.) And which of the two builds has its
     READ-ONLY DATA in an executable segment? That is
     the whole security difference, and it is one flag.

  5. Strip both binaries. How much of the 52x is the
     symbol table rather than the code? (Hint:
     objcopy --strip-all, then compare .text.)
</pre>
                </div>
                <p>Exercise 4 is the one that closes the loop on the first finding in this concept, and it is a one-flag experiment with a clean answer. <strong><code>-z noseparate-code</code> takes four <code>PT_LOAD</code>s down to three</strong> &mdash; the read-only data segment merges into the headers segment &mdash; and the script you were given changes accordingly, because the comment on line 1 literally names the flag. <code>ld --verbose</code> gives you a different 276-line script depending on your <code>-z</code> flags, and that is a fact worth holding onto before you go editing either one.</p>
                <p>Exercise 2 is the one that teaches the real constraint. Whether the static <code>getaddrinfo</code> works or fails tells you what your distribution&rsquo;s static libc can do, and <strong>either answer is instructive</strong>: if it fails, you have the classic limitation; if it works, you have a build that silently links against a libc that will disagree with a different one. Both outcomes are things you need to know before shipping.</p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>This is the first of the two closing concepts, and it is where the course&rsquo;s earlier threads converge on one number. <a href="/courses/reloc/lessons/pie-flags">The Flags, and Which One Is Which Kind</a> drew the 3&times;3 matrix of codegen against link flags and found four cells where the two disagree. <a href="/courses/link/lessons/link-phdrs">PHDRS and the -T Surprise</a> found that a script is a <em>third</em> participant which overrides both. <strong>This concept shows what that override is for:</strong> <code>-static</code> changes the <code>e_type</code> to <code>ET_EXEC</code>, the script then lays the image at a fixed address, and the kernel maps it with no loader involved. The <code>0x400000</code> is not a compiler decision or a linker decision in isolation &mdash; it is the script answering a question the code model asked.</p>
                <p>The connection to <a href="/courses/elf/lessons/entry-point">the ELF course's entry-point concept</a> is the mechanism that makes a static binary work at all, and it is worth restating as the reason the whole thing is possible. <code>PT_INTERP</code> is a program header whose <em>contents</em> are a pathname. A dynamic binary is executed by a two-step process: the kernel maps the interpreter, the interpreter maps the program, and the interpreter reads <code>e_entry</code> from the program and jumps there. A static binary is one step: the kernel maps it and jumps to <code>e_entry</code>. <strong>Everything <code>-static</code> removes is the first half of that two-step process</strong>, and the segment measurements above are simply the absence of one header in a fourteen-header file.</p>
                <p>And the <code>-z separate-code</code> finding connects to the <a href="/courses/reloc/lessons/pie-randomize">randomisation concept</a> in a way that is easy to miss. That concept measured that a PIE gets a random base and argued that attacks (a) hard-coded addresses and (b) code pointers in <code>.data</code> stop working. Attack (d) &mdash; a vtable or function pointer in read-only data &mdash; was listed as <em>not</em> defeated by PIE, and the fix given was RELRO. <strong>Now you can see why the flag that produces four segments instead of two is the same decision:</strong> <code>separate-code</code> exists so that the read-only data segment &mdash; where those function pointers live &mdash; is in pages that are not writable, and merging it back with the headers would put it somewhere the loader might have to treat differently. <strong>Layout and security policy are the same lever.</strong></p>
                <p>Forward to the last concept, which is the buildable artifact and the reason this course exists. Everything so far has been reading a 276-line file and running flags. <a href="/courses/link/lessons/link-write-script">Writing One Yourself</a> makes you <em>generate</em> one, verify its effect, and run the result &mdash; and the tool for it, <code>linklab.py</code>, is deliberately shaped around the three things this course established: that a script is a program you can edit, that its effect is checkable rather than assumed, and that a linker will not tell you when your edit did nothing.</p>
                <p>One connection outward, and it is the honest limit of everything in this module. <strong>Every number on this page was measured on a hosted Linux target with a dynamic loader present.</strong> The <code>e_type</code> change, the removed <code>PT_INTERP</code>, the four segments, the 52&times; &mdash; all real, all reproducible from one script. But the question that matters for a static binary is &ldquo;does it run on the machine I did not build it on&rdquo;, and <strong>that is a question this toolchain cannot answer and this course does not claim to.</strong> It is the same limit the Relocations course recorded for AArch64: the mechanism is measured, the execution is not.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/link/lessons/link-orphans">Previous: The Sections the Script Forgot</a></span>
                <span>Next: <a href="/courses/link/lessons/link-write-script">Writing One Yourself</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
