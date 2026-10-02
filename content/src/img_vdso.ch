// Executable Images and OS Loading — Module 2: Reading the Values
// Concept: a shared library the kernel synthesises and backs with nothing.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_img_vdso() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The vDSO: An ELF File With No File — Underlayer")
    page.appendTitle(&title)

    render_lesson_nav(&mut page)
    render_lesson_css(&mut page)

    #html {
        <div class="lesson img-lesson">
            <a href="/courses/img" class="back-link">Back to course</a>
            <h1>The vDSO: An ELF File With No File</h1>
            <div class="lesson-meta">23 min &middot; Module 2: Reading the Values &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Every dynamic process on Linux maps a shared library that has no file on disk. It appears in <code>/proc/&lt;pid&gt;/maps</code> under the name <code>[vdso]</code> &mdash; square brackets, which is the kernel&rsquo;s way of saying <em>there is no path here</em>. It has an address, given to the process in the auxv as <code>AT_SYSINFO_EHDR</code>. And it has, if you read it, a perfectly ordinary ELF header.</p>
                <p>Here is that header, read out of the running process&rsquo;s own memory:</p>
                <div class="hex-dump">
                    <pre>$ cd courses/img/assets/samples &amp;&amp; ./build_samples.sh 2&gt;&amp;1 | sed -n '/I4/,/I5/p'
     size, e_ident magic, e_type, e_machine, e_phentsize, e_phnum, e_phoff:
      vdso_size=8192
      magic=7f454c46
      e_type=3 e_machine=62 e_phentsize=56 e_phnum=6 e_phoff=64
      AT_SYSINFO_EHDR=136793659318272
      EHDREQ_VDSO=1
</pre>
                </div>
                <p><strong><code>7f 45 4c 46</code> is <code>\x7fELF</code>. <code>e_type = 3</code> is <code>ET_DYN</code>. <code>e_machine = 62</code> is <code>EM_X86_64</code>. Six program headers, 56 bytes each, at offset 64.</strong> That is a well-formed 64-bit shared object, and there is no file anywhere that contains it.</p>
                <p>Why should a course about the kernel&rsquo;s handoff care? Because it is the cleanest available proof of what the previous five courses described. <strong>Every one of them taught you to read an ELF file that a compiler produced. This is an ELF file the kernel produced, at run time, for every process it creates</strong> &mdash; and the same header fields, in the same order, at the same offsets, mean exactly what they meant in <code>readelf</code> output.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Why a kernel builds a library at all. The motivation is a performance argument, and it is worth stating because it explains the shape of the solution:</p>
                <div class="formula">
  gettimeofday() is very common. time(2) is
  cheap to COMPUTE.

  but a syscall is expensive to ENTER:
      the mode switch, the register save,
      the trap. ~1000 cycles, versus ~20 for
      the addition that does the actual work.

  so on x86 the CPU has an instruction:
      RDTSC  read the timestamp counter

  that instruction is fast, and it lets you
  compute a high-resolution time with no
  syscall at all.

  but the counter's frequency is per-CPU and
  needs calibrating against a reference --
  which needs a syscall.

  so: the kernel does the calibration ONCE,
  writes the result into a small code+data
  image, and gives every process a pointer to
  its own copy.

  that image is the vDSO. it is a shared
  object, so each process gets a private copy
  and the calibration can differ per CPU.
                </div>
                <p>So the vDSO is not a weird exception. <strong>It is the ordinary machinery of the chain, with the linker step removed.</strong> It is <code>ET_DYN</code>, so the kernel maps it at a base and reports that base in the auxv &mdash; the same <code>AT_BASE</code> mechanism as the dynamic linker, and the reason <code>AT_SYSINFO_EHDR</code> exists as a separate entry at all.</p>
                <p>What makes it a teaching object is that <strong>you can read it.</strong> There is no <code>readelf</code> that will open it, because there is no file. But the header is <em>in your address space</em>, so you can open <code>/proc/self/mem</code>, seek to the address <code>/proc/self/maps</code> gave you, and read sixty-four bytes. That is the whole technique, and it is the same technique the artifact uses for every other check in this course.</p>
                <div class="formula">
  1. read /proc/self/maps, find the line whose
     last field is "[vdso]"   -> lo, hi
  2. open /proc/self/mem
  3. seek to lo, read 64 bytes
  4. that is an Elf64_Ehdr. parse it with the
     same code you already wrote for a file.

  there is no step 5. it is not a special
  case. it is an ELF file, obtained unusually.
                </div>
            </div>

            <div class="unit unit-reality">
                <h2>What Is Measured, and What Is Not</h2>
                <p>The header, exactly:</p>
                <div class="hex-dump">
                    <pre>$ python3 crosscheck.py 2&gt;&amp;1 | sed -n '/G4/,$p' | head -9
  G4    7 passed   0 failed
</pre>
                </div>
                <p>Each of those seven is a real check, run on every invocation:</p>
                <ul>
                    <li><strong>The magic is <code>7f454c46</code>.</strong> Not &ldquo;looks like ELF&rdquo; &mdash; the four bytes, compared exactly.</li>
                    <li><strong><code>e_type</code> is 3.</strong> <code>ET_DYN</code>, so it is a shared object and the kernel must give it a base. This is not a label; it is the reason for the <code>AT_SYSINFO_EHDR</code> entry.</li>
                    <li><strong><code>e_machine</code> is 62.</strong> <code>EM_X86_64</code>, so it was built for this CPU and cannot be run on another architecture &mdash; which is true of it and <em>not</em> true of the executable, whose architecture comes from its own header. <strong>Two ELF images in one process, built for the same machine, and the kernel produced one of them.</strong></li>
                    <li><strong><code>e_phentsize</code> is 56 and <code>e_phoff</code> is 64.</strong> The standard 64-bit layout, identical to every other file in this course. The kernel emits the same structure a linker would.</li>
                    <li><strong>It is 8192 bytes.</strong> Two pages, on this kernel. Small enough to be built at run time in microseconds, which is the design constraint.</li>
                    <li><strong><code>EHDREQ_VDSO = 1</code></strong> &mdash; and this one is a story, because getting it wrong was instructive.</li>
                </ul>
                <p>The last item deserves its own explanation, because the mistake is a good one to have made. The natural way to check &ldquo;does <code>AT_SYSINFO_EHDR</code> point at the vDSO?&rdquo; is to run the auxv dumper in one process and the <code>/proc/maps</code> reader in another, then compare. <strong>That cannot work, because they are two different processes and ASLR puts the vDSO somewhere different in each.</strong> The first version of this script did exactly that and printed two unrelated addresses, which looked like a bug in the kernel.</p>
                <p>The fix is to compare <em>within one process</em>: have the measuring program read its own auxv <em>and</em> its own map, and print the two side by side. It does, and they are equal &mdash; <code>EHDREQ_VDSO=1</code>. <strong>Any time you verify something a randomiser perturbs, both observations must come from the same process, or you are comparing two samples of a distribution and calling it a match.</strong> That is a general rule about experiments, and this course hit it hard enough to be worth stating as a rule rather than a footnote.</p>
                <div class="hex-dump">
                    <pre>$ python3 stackwalk.py 2&gt;&amp;1 | grep vdso
  [ok  ] AT_SYSINFO_EHDR == the base of the [vdso] mapping
         -- 0x7f92255a0000 vs 0x7f92255a0000
</pre>
                </div>
                <p>And the square brackets, which are the detail that makes the whole thing click: <code>[vdso]</code>, <code>[stack]</code>, <code>[heap]</code>. The kernel uses brackets for a region it made itself and has no file for. <strong>Every one of those is the kernel writing into an address space, and the vDSO is the one where it also wrote a file&rsquo;s worth of structure into it.</strong></p>
            </div>

            <div class="unit unit-example">
                <h2>Reading It Yourself</h2>
                <p>The complete program, and it is short. Everything here has appeared in this course already; that is the point.</p>
                <div class="hex-dump">
                    <pre>#include &lt;stdio.h&gt;
#include &lt;string.h&gt;
#include &lt;stdlib.h&gt;

int main(void) {
    unsigned long lo = 0, hi = 0;
    FILE *f = fopen("/proc/self/maps", "r");
    char line[512];
    while (fgets(line, sizeof line, f)) {
        unsigned long a, b; char p[8], d[64];
        if (sscanf(line, "%lx-%lx %7s %*s %*s %*s %63s",
                   &amp;a, &amp;b, p, d) &gt;= 4 &amp;&amp; strstr(d, "vdso")) {
            lo = a; hi = b;
        }
    }
    fclose(f);

    /* the kernel's own view of its own memory */
    FILE *m = fopen("/proc/self/mem", "rb");
    unsigned char h[64];                 /* exactly one Elf64_Ehdr */
    fseek(m, lo, SEEK_SET);
    if (fread(h, 1, 64, m) != 64) return 1;
    fclose(m);

    printf("magic %02x%02x%02x%02x\n", h[0],h[1],h[2],h[3]);
    printf("e_type %d e_machine %d\n",
           h[16] | h[17]&lt;&lt;8, h[18] | h[19]&lt;&lt;8);
    return 0;
}
</pre>
                </div>
                <p>Three things to notice. <strong>It is 64 bytes and no more</strong> &mdash; an <code>Elf64_Ehdr</code> is a fixed-size structure, which is the only reason this is possible. <strong>Every field is a hand-decoded little-endian byte pair</strong>, because there is no <code>readelf</code> and there is no file, so the struct layout has to be written out. <strong>And the <code>sscanf</code> has a <code>%*s</code> in it for the file offset</strong> &mdash; which is skipped, not parsed, because this region has no file and therefore no offset worth having.</p>
                <p>That last detail is the real signature of the vDSO. Compare it to the same <code>maps</code> line for an ordinary library:</p>
                <div class="hex-dump">
                    <pre>$ ./maps | grep -E 'vdso|ld-linux' | head -3
  71e4c0d45000-71e4c0d47000 r-xp 00000000                  [vdso]
  7881a3b73000-7881a3b74000 r--p 00000000 103:02 8678400  /usr/lib/.../ld-linux-x86-64.so.2
  7881a3b74000-7881a3b81000 r-xp 00001000 103:02 8678400  /usr/lib/.../ld-linux-x86-64.so.2
</pre>
                </div>
                <p><strong>Look at the vDSO line: no device, no inode, no path.</strong> The <code>rwxp</code> permissions and the address range are there, because those are the kernel&rsquo;s own bookkeeping. Everything that would identify a backing file is blank, because there is none. That single line is the entire concept: a mapped, executable, ELF-shaped thing with nothing behind it.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Try It Yourself</h2>
                <div class="hex-dump">
                    <pre>$ cd courses/img/assets/samples
$ ./build_samples.sh 2&gt;&amp;1 | sed -n '/I4/,/I5/p'
$ python3 crosscheck.py 2&gt;&amp;1 | sed -n '/G4/,/G5/p'
$ ./maps | grep vdso
</pre>
                </div>
                <p>Then go past what was measured, in a controlled way:</p>
                <div class="hex-dump">
                    <pre>  1. Read the vDSO's PROGRAM HEADERS, not just its
     header. Six of them at offset 64. Print
     p_type, p_flags, p_offset, p_vaddr, p_filesz,
     p_memsz for each. (There will be two PT_LOADs
     and a PT_GNU_RELRO among others, and the PT_LOAD
     vaddrs will be RELATIVE TO ZERO because
     e_type is ET_DYN. This is the same program
     header table format from
     /courses/elf/lessons/program-header-table,
     in a file nobody compiled.)

  2. Use AT_SYSINFO_EHDR as the base and add each
     PT_LOAD's p_vaddr. Where do they land
     relative to the 8192 bytes you measured? Do
     they fit? (They must. That is checkable
     arithmetic and it is a real check that the
     header you read belongs to the mapping you
     read it from.)

  3. Look for the SYMBOL TABLE. The vDSO's
     section headers are all zero on most kernels
     (it is built for the loader, which wants
     program headers, not sections). Confirm that,
     and then explain what that implies: the
     vDSO cannot be read with readelf-style
     tooling even in principle, because it has no
     section header table to walk.

  4. Compare the vDSO across two processes, properly.
     Run ./maps | grep vdso twice. The ADDRESSES
     differ (ASLR). The SIZE does not. Then run
     it twice in ONE process and confirm the
     address is stable. (The stability is the
     point: the vDSO is mapped once, at process
     creation, and never moves.)

  5. strace -e trace=clock_gettime a program
     that calls it, and one that does not, and
     count the syscalls. (Zero for a program
     using the vDSO path. This is the entire
     reason the vDSO exists, and you can watch
     it not happen.)
</pre>
                </div>
                <p>Exercise 1 is the one that ties this course to the whole chain, because it makes the vDSO into a <a href="/courses/elf/lessons/program-header-table">program header table</a> you have to parse. <strong>Same structure, same field order, same 56-byte record &mdash; in a file that no toolchain produced.</strong> And the <code>p_vaddr</code> values are relative to zero precisely because <code>e_type</code> is <code>ET_DYN</code>, which is the rule the <a href="/courses/reloc/lessons/pic-violation">relocations course</a> established for shared objects and the linker-script course found written into the default script.</p>
                <p>Exercise 3 has the most interesting answer. <strong>The vDSO has no section header table, so the family of tools that navigate ELF by section simply cannot read it.</strong> That is not a defect &mdash; sections exist for linkers, and the vDSO is never linked, only mapped. It is a clean demonstration that the two halves of ELF serve different consumers, and that a format can be completely valid while being unreadable by the tools you already know. The program header table is the kernel&rsquo;s half; the section header table is the toolchain&rsquo;s; the vDSO is a file that only has the first one.</p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>The most direct connection in the course is to <a href="/courses/dyn/lessons/dyn-dlopen">the dynamic linking course&rsquo;s <code>dlopen</code> concept</a>, and it is a genuine contrast rather than a repetition. That concept covered loading a library at run time from a path, and the loader&rsquo;s search rules, and the mode bits. <strong>Every one of those concerns evaporates for the vDSO, because the kernel is the loader and there is no path to search.</strong> No search path, no <code>DT_NEEDED</code>, no scope insertion, no symbol resolution &mdash; just an address in the auxv. It is the <code>dlopen</code> mechanism with the entire search problem designed out, which is a useful thing to have seen precisely because the search problem is invisible in the normal case.</p>
                <p>The connection to <a href="/courses/dyn/lessons/dyn-tls-block">Where the Thread Blocks Come From</a> is about who allocates. That concept measured the loader allocating TLS storage a linker could not. <strong>The vDSO is the same idea taken further: the kernel allocating an entire ELF image that no linker, compiler, or human wrote.</strong> Both exist because a per-process value cannot be baked into a file. The difference is that the TLS block is data the linker described and the kernel supplied, while the vDSO is structure the kernel both described and supplied.</p>
                <p>And the connection to the beginning of the chain is the one that makes the course&rsquo;s title true. <a href="/courses/obj/lessons/obj-intro">The object-file course</a> began with &ldquo;an ELF file is a header, a program header table, a section header table, and sections.&rdquo; <strong>The vDSO is the case that proves which of those the kernel cares about</strong>: header, program headers, sections, and no section header table at all. The kernel built it, so the kernel needed only the parts the kernel reads. Everything the previous five courses taught you about the section header table, the string table, and the symbol table is real and important and <em>absent</em> here &mdash; and its absence is the cleanest available statement of what the two halves of the format are for.</p>
                <p>One connection forward, which is the next concept. The vDSO is mapped at a chosen address like everything else, and it is not the only thing. <a href="/courses/img/lessons/img-place">Where the Kernel Put Everything</a> puts the whole address space on the page, with the floor it will not go below and the reason a hint is not a request.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/img/lessons/img-entries">Previous: What Each Entry Is For</a></span>
                <span>Next: <a href="/courses/img/lessons/img-place">Where the Kernel Put Everything</a></span>
            </div>
        </div>


    render_lesson_js(&mut page)
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
