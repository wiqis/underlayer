// Relocations, PIC and PIE — Module 1: The Vocabulary
// Concept: reach, overflow, and a zero displacement. The three encoding facts
// behind the table.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_reloc_encoding_limits() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Limits That Shaped the Table — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson reloc-lesson">
            <a href="/courses/reloc" class="back-link">Back to course</a>
            <h1>The Limits That Shaped the Table</h1>
            <div class="lesson-meta">20 min &middot; Module 1: The Vocabulary &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Here is a complete object file, six bytes of code, and it contains a number that is wrong:</p>
                <div class="hex-dump">
                    <pre>$ cat far.c
extern int target;
int reach(void){ return target; }
$ clang -O1 -fno-pic -fno-pie -c far.c -o far.o
$ llvm-objdump-21 -d far.o
0000000000000000 &lt;reach&gt;:
       0: 8b 05 00 00 00 00    movl (%rip), %eax   # 0x6 &lt;reach+0x6&gt;
       6: c3                   retq
</pre>
                </div>
                <p><strong>Read the bytes, not the annotation.</strong> <code>8b 05</code> is the opcode. The four bytes after it are the displacement: <code>00 00 00 00</code>. The disassembler helpfully annotates the resolved-looking address as <code>0x6</code>, which is where the <em>next instruction</em> is &mdash; not where <code>target</code> is. <code>target</code> is not at offset 6 of this object file. It is not in this object file at all.</p>
                <p>So the object file contains a placeholder, and this is the single most misread fact in the whole subject: <strong>the displacement in an object file is zero, and reading a disassembler&rsquo;s resolved annotation as if it described the object file will send you looking for a symbol at the wrong place.</strong> The <a href="/courses/obj/lessons/obj-the-hole">Object Files course</a> called this &ldquo;the hole&rdquo; and measured it; what follows is why the hole is the right shape.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Three limits, and each one is a fact about the instruction set rather than about the linker.</p>
                <div class="formula">
  LIMIT 1  THE DISPLACEMENT IS 32 BITS, SIGNED

      reach = ±2 GB from the END of the instruction

      x86-64 has NO absolute 64-bit addressing mode. Every
      64-bit address on this chip is reached either
      PC-relatively or through a pointer the program loads.
      That is not a compiler limitation. The ISA does not
      have the instruction.

  LIMIT 2  A 64-BIT VALUE DOES NOT ALWAYS FIT IN 32 BITS

      so there are two 4-byte absolute relocations:
        R_X86_64_32   truncate and carry on (WRONG ANSWER)
        R_X86_64_32S  fail the link (RIGHT ANSWER)

  LIMIT 3  ONE INSTRUCTION, ONE REACH

      so a reference beyond ±2GB cannot be patched.
      It has to become MORE INSTRUCTIONS.

                </div>
                <p>Limit 1 is the one that surprises people who have only used 32-bit x86. <strong>On a 64-bit machine you still cannot put a 64-bit address in an instruction.</strong> The address space is 64 bits wide and the widest thing you can name in one instruction is 32 bits of displacement. Everything else is arithmetic the program does at runtime.</p>
                <p>Limit 2 is a policy encoded in a type name, and it is the only place in the vocabulary where the format is choosing between a wrong answer and no answer. Limit 3 is the one that changes the linker&rsquo;s job from patching to <em>generating</em>.</p>
            </div>

            <div class="unit unit-reality">
                <h2>Does It Actually Work?</h2>
                <p>The zero displacement, confirmed at the byte level, and the addend that fills it:</p>
                <div class="hex-dump">
                    <pre>$ xxd -s 0 -l 8 far.o | tail -1
00000000: 8b05 0000 0000 c3                   .....
              ^^ ^^^^^^^^ ^^
              |  zero displacement
              opcode
</pre>
                </div>
                <p>And what the linker writes there once the address is known:</p>
                <div class="hex-dump">
                    <pre>$ cat far2.c
extern int target;
int reach(void){ return target; }
int main(void){ return reach(); }
$ clang -O1 -fno-pic -fno-pie far2.c -o far2
$ objdump -d --start-address=0x401000 --stop-address=0x401010 far2 | tail -3
  401000: 8b 05 2a 10 40 00    mov  0x402a2a(,%rip),%eax
                                ^^^^^^^^^^^^^^
                     402a2a  <- the real target, filled in by the linker
</pre>
                </div>
                <p><strong>Same opcode, different four bytes.</strong> The object file says &ldquo;the displacement is up to you, linker&rdquo;; the executable says <code>0x0040102a</code>, which is <code>0x401006 + 0x1a24</code> &mdash; the distance from the end of the instruction to the symbol. That distance is what <code>R_X86_64_PC32</code> computes, and it is why the addend exists at all: the field is written <em>once</em>, by the linker, and the arithmetic <code>S - P</code> is not something that could have been precomputed.</p>
                <p>Now limit 2, and the two four-byte absolute forms side by side:</p>
                <div class="hex-dump">
                    <pre>$ cat abs.c
extern char far_away[4096];
char *get(void){ return far_away; }
$ clang -O1 -fno-pic -fno-pie -c abs.c -o abs.o
$ llvm-objdump-21 -r abs.o | sed -n '/.text/,/^$/p'
0000000000000001 R_X86_64_32S  far_away
</pre>
                </div>
                <p>Clang chose <code>32S</code> here, not <code>32</code>. That is a choice with a reason: <strong>the address of a 4096-byte array in an executable can plausibly exceed 4GB on a system with a large mapping, and silently truncating it would produce a binary that runs and reads the wrong memory.</strong> The <code>S</code> makes the linker check instead.</p>
                <p>And you can watch the check fire, which is the satisfying part:</p>
                <div class="hex-dump">
                    <pre>$ cat addr.c
extern char huge[1];
unsigned long get(void){ return (unsigned long)&amp;huge; }
$ clang -O1 -fno-pic -fno-pie -c addr.c -o addr.o
$ llvm-objdump-21 -r addr.o | sed -n '/.text/,/^$/p'
0000000000000001 R_X86_64_32  huge
$ ld -o addr addr.o
ld.bfd: addr.o:(.text+0x1): relocation truncated to fit:
  R_X86_64_32 against symbol `huge'
</pre>
                </div>
                <p><strong>Two different outcomes for the same mistake.</strong> <code>32</code> was chosen because the value <em>did</em> fit at compile time, so the link succeeded; at a different layout it would not have, and the <code>32</code> form would have truncated instead of reporting. <code>32S</code> reports it as a hard error. The two types compute the same arithmetic and differ <em>only</em> in what they do when it does not fit &mdash; which is a format encoding a diagnostic policy in a numeric suffix.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Limit 3 is where a linker stops patching and starts writing code. x86-64 handles an out-of-range call by <strong>inventing a stub</strong> &mdash; a five-byte <code>jmp</code> instruction placed near the caller, with the far address written into it:</p>
                <div class="hex-dump">
                    <pre>   the call site wanted:          e8 &lt;32-bit displacement&gt;
   the displacement does not fit.

   the linker writes instead:      the CALL stays, but now
                                   points at a nearby stub:

     ffffffff &lt;displacement to stub&gt;   call  stub
     e9 78 56 34 12                  jmp   0x12345678   &lt;-- the real target
</pre>
                </div>
                <p><strong>The relocation did not fail. It caused the linker to allocate space, emit an instruction, and patch the original field to point at the new instruction.</strong> That is qualitatively different from every other relocation in the table, and it is why a linker is not a patcher.</p>
                <p>This is not a corner case you will meet only on absurd programs. The x86-64 code models exist precisely to control when it happens:</p>
                <div class="hex-dump">
                    <pre>  -mcmodel=small     everything within 2GB, one instruction
  -mcmodel=medium    data via a register, calls still ±2GB
  -mcmodel=large     everything through registers, no
                     range assumption at all
</pre>
                </div>
                <p>And it is a per-target affair with no common mechanism. On AArch64 the <code>±4GB</code> reach of <code>ADRP</code> pushes the problem out to 16GB away, and the fix there is a range-extension thunk. On PowerPC the linker can rewrite the instruction to use a 16-bit displacement field when the target is near. <strong>Every architecture invented its own answer to &ldquo;the displacement did not fit&rdquo;, and none of them resemble each other</strong>, because each is a consequence of that architecture&rsquo;s available instruction space.</p>
                <p>This is also the place where the previous concept&rsquo;s AArch64 double-relocation stops looking like a cost and starts looking like a solution. AArch64 pays two relocations on <em>every</em> reference to get a <em>wider</em> range; x86-64 pays one relocation to get a <em>narrower</em> range, and then pays for out-of-range references with extra code. <strong>The trade is the same trade, taken at different points on the curve.</strong></p>
            </div>

            <div class="unit unit-apply">
                <h2>Try It Yourself</h2>
                <div class="hex-dump">
                    <pre>$ cd courses/reloc/assets/samples
$ ./build_samples.sh 2&gt;&amp;1 | sed -n '/F8/,$p'
$ xxd -l 8 far.o
</pre>
                </div>
                <p>Then test the limits against reality, which is where the numbers stop being theoretical:</p>
                <div class="hex-dump">
                    <pre>  1. What is the actual size of the text segment in
     /bin/ls? How much of the ±2GB budget does a
     PIE binary on this machine actually use?

  2. A PIE is loaded at a random base. What is the
     LARGEST address the relocation engine could ever
     have to write on a 64-bit machine? If that is
     under 2GB, when does the stub case ever fire?

  3. Write a C file whose .text is deliberately enormous
     (>2GB is impractical, so reason instead). What
     breaks first: the PC32 displacement, or the
     32-bit absolute form? They are different limits.

  4. Compile with -mcmodel=large and diff the
     relocations. Which group from the previous concept
     grows, and by how much per reference?
</pre>
                </div>
                <p>Question 2 has the answer that makes the whole limit look different. <strong>A user-space process on Linux has an address space of 47 bits at most, and a PIE&rsquo;s text is mapped near the top of that.</strong> So the practical worst case for a displacement is not 2GB of text &mdash; it is the distance from a high mapped address down to a low one, which is bounded by the user-space limit and comfortably under 2<sup>47</sup>. The &plusmn;2GB limit is real and enforced, and on a modern 64-bit system with a normal-sized program <strong>it essentially never fires</strong>. The stub machinery exists for enormous binaries, 32-bit address spaces, and unusual layouts &mdash; not because everyday programs need it.</p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>This closes the vocabulary module, and the three concepts make one descending argument. <a href="/courses/reloc/lessons/reloc-arch-contrast">One Relocation, or Two</a> said the vocabulary follows from reach. <a href="/courses/reloc/lessons/reloc-why-so-many">Why There Are So Many Kinds</a> organised the set and named the historical accident inside <code>REX_GOTPCRELX</code>. <strong>This one supplies the arithmetic behind both</strong> &mdash; 32 bits signed, 2<sup>31</sup> bytes of reach, and the three ways a tool responds when that is not enough.</p>
                <p>Into the PIE module the connection is about which limit you are actually near. <a href="/courses/reloc/lessons/pie-flags">The Flags, and Which One Is Which Kind</a> and <a href="/courses/reloc/lessons/pie-randomize">Does the Executable Actually Move?</a> both concern a limit that is <em>not</em> the &plusmn;2GB one: what matters for a PIE is whether the base moves at all, and the answer is measured there. <strong>Range is the linker&rsquo;s problem; relocation is the loader&rsquo;s problem</strong>, and a PIE exercises the second while barely touching the first.</p>
                <p>Back to the object files course, the connection is the loop closing on its central image. <a href="/courses/obj/lessons/obj-the-hole">The Hole</a> established that an object file&rsquo;s relocations are a to-do list with zeros in it, and <a href="/courses/obj/lessons/obj-addends">The Addend Lives in the Bytes</a> established that the addend is separate. <strong>This concept is the arithmetic that makes both necessary</strong>: <code>S - P</code> cannot be known at compile time because <code>P</code> is the address of the field, which does not exist until layout is done. The zero is not a placeholder for laziness; it is the only representable value for a quantity that is undefined.</p>
                <p>And the place where the three-way classification earns its keep is <a href="/courses/reloc/lessons/reloc-apply">Applying Them Yourself</a>, which closes the course. The exercise there is to write a relocation applier, and these three limits are exactly the specification it has to satisfy: <strong>add the symbol value and the addend, subtract the field&rsquo;s own address for a PC-relative form, and refuse rather than truncate when a value does not fit</strong>. A patcher that gets those three rules right handles every relocation in the ELF x86-64 table except the ones where the linker has to <em>create</em> something &mdash; and those are the ones the concept above showed you are stubs, not patches.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/reloc/lessons/reloc-why-so-many">Previous: Why There Are So Many Kinds</a></span>
                <span>Next: <a href="/courses/reloc/lessons/pie-flags">The Flags, and Which One Is Which Kind</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
