// Object Files — Module 3: The Fixup
// Concept: position independence as a choice of relocation set, and why -fPIE
// and no flag produce byte-identical relocations.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_obj_pic() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Position Independence — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson obj-lesson">
            <a href="/courses/obj" class="back-link">Back to course</a>
            <h1>Position Independence</h1>
            <div class="lesson-meta">24 min &middot; Module 3: The Fixup &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Everything so far in this module has been about a fixup's arithmetic. This concept is about something more consequential: <strong>which fixups you emit in the first place.</strong> That choice is what &ldquo;position independence&rdquo; means at the object-file level, and it is a decision a compiler makes, not a property a format has.</p>
                <p>Put plainly: a non-position-independent object asks the linker for <em>absolute addresses</em>, and therefore requires the linker to know where everything will be. A position-independent object asks for <em>distances</em>, and therefore works anywhere. <strong>That is the whole idea, and it is entirely expressed in the relocation types.</strong> No new attribute, no flag in the file header, no structural difference &mdash; the same mechanism, asked a different question.</p>
                <p>It also matters for a reason the previous concepts did not prepare you for. <strong>Changing the relocation type changes the instruction encoding, which changes every offset after it.</strong> So position independence is not a flag a linker can ignore or a property it can add later. By the time a linker sees the file, the decision has been made and baked into the byte offsets.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Two questions a relocation can ask, and the answer determines whether the code can be moved:</p>
                <div class="formula">
  AN ABSOLUTE RELOCATION asks:
      "what is the address of this symbol?"
    the answer is a fixed number once layout is done
    -> the code is welded to that layout
    -> it CANNOT be moved afterwards

  A RELATIVE RELOCATION asks:
      "how far is this symbol from HERE?"
    the answer is a distance, and distances survive translation
    -> the whole object can be shifted and still work

  and a third kind, for shared libraries specifically:

  A GOT-RELATIVE RELOCATION asks:
      "how far is this symbol's GOT slot from HERE?"
    -> one extra indirection, and now the DATA is relative
       too, without needing a distance from here at all
</div>
                <p><strong>And that third kind is the interesting one, because it is the only one that solves a problem the second kind cannot.</strong> Being able to move the object is not the same as being able to move <em>its data</em> independently of the code. Consider a global variable: a <code>PC32</code> reference to it is a distance from the instruction to the variable, and that distance is stable only as long as the code and the data move <em>together</em>. They do not, in a shared library, because the data has to be writable while the code is not &mdash; and on a system with W^X they cannot even be on the same page.</p>
                <p>So the data must be addressed through a table of addresses that the loader can fill in with wherever things actually landed. <strong>That table is the Global Offset Table, and referencing through it is what buys full independence.</strong> The cost is one memory indirection on every global access, and the benefit is that a library can be loaded at an address nobody chose in advance.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>One source file, one machine, three builds. The <code>.text</code> relocations from each, from <code>llvm-objdump-21 -r</code>:</p>
                <div class="hex-dump">
                    <pre>  OFFSET (no flag)   OFFSET (-fPIC)    TYPE (no flag)      TYPE (-fPIC)

  0x04              0x05             R_X86_64_PC32         R_X86_64_REX_GOTPCRELX
  0x0a              0x0e             R_X86_64_PC32         R_X86_64_REX_GOTPCRELX
  0x21              0x21             R_X86_64_PLT32        R_X86_64_PLT32
  0x33              0x33             R_X86_64_PC32         R_X86_64_REX_GOTPCRELX

  .data reloc:     R_X86_64_64       in all three builds
  internal calls:  R_X86_64_PC32 x3   in all three builds
</pre>
                </div>
                <p>Three rows change under <code>-fPIC</code> and one does not, and the pattern is precise.</p>
                <h3>The calls do not change</h3>
                <p>The call at <code>0x21</code> is <code>PLT32</code> in all three builds, and so are the three internal calls. <strong>The call path is already indirection-based, so position independence costs it nothing.</strong> A call to an undefined function must go somewhere the linker decides, and that somewhere is the PLT; a call to a function in the same object is a direct relative branch, and a direct relative branch is already position-independent.</p>
                <p>Compare that to the previous concept's data reference, which is an absolute address by default. <strong>Calls were position-independent before anybody asked, and data was not.</strong> That asymmetry is the whole reason <code>-fPIC</code> changed exactly three relocations out of eight.</p>
                <h3>The data references all become GOT-relative</h3>
                <p>All three global data references &mdash; <code>global_counter</code>, <code>uninitialised</code> and <code>message</code> &mdash; switch from <code>PC32</code> to <code>REX_GOTPCRELX</code>. And the name is worth reading carefully, because it is three relocations wearing a trenchcoat:</p>
                <ul>
                    <li><strong><code>REX</code></strong> is an x86-64 prefix byte, not part of the relocation at all. It is a marker the linker needs for a historical reason: the <code>mov</code> form that can use a GOT-relative operand was originally a <code>call</code> opcode, so the linker has to know it is patching a <code>mov</code>. <strong>The prefix is the format's way of saying "this particular encoding is ambiguous, here is how to disambiguate it."</strong></li>
                    <li><strong><code>GOTPCREL</code></strong> is the arithmetic: PC-relative, and the value it computes is the address of a <em>GOT slot</em> rather than the symbol's address.</li>
                    <li><strong><code>X</code></strong> marks the ambiguity above.</li>
                </ul>
                <div class="callout">
                    <strong>And the <code>REX</code> prefix is why the offsets moved.</strong> The data reference at <code>0x04</code> became <code>0x05</code>, and the one at <code>0x0a</code> became <code>0x0e</code> &mdash; a shift of one byte and then four. <strong>The instruction got longer, because the GOT-relative encoding needs a prefix byte the plain RIP-relative form does not.</strong> Everything after the first one slid along with it.
                </div>
                <h3>-fPIE is identical to no flag, and that is the surprise</h3>
                <p>The third build used <code>-fPIE</code>, and its relocation set is <strong>byte-for-byte the same as the build with no flag at all.</strong> Same types, same offsets, same eight records.</p>
                <p>That is genuinely counter-intuitive if you have absorbed the slogan &ldquo;PIE means position independent&rdquo;, and the reason is that <strong>the two flags are solving different problems with different amounts of freedom.</strong></p>
                <div class="formula">
  -fPIC   build a SHARED LIBRARY.
          It may be loaded at ANY address, chosen by
          whoever loads it, on a machine nobody pictured
          when it was compiled.
          -> needs the GOT for its data. COSTS an
             indirection per global access.

  -fPIE   build an EXECUTABLE that is position
          independent.
          The executable is the FIRST thing mapped, and
          the loader may place it near its link address.
          -> its own data moves WITH it, so PC-relative
             distances are already correct.
          -> COSTS NOTHING over the non-PIE build.

  so: "position independent" is two different
  requirements, and only the harder one pays.
</div>
                <p><strong>And that is the finding worth taking away: the expensive one is for libraries, not for executables.</strong> A PIE executable is a hardening measure &mdash; it defeats fixed-address exploits by making the code unreadable until it is mapped. A shared library is a <em>deployment</em> requirement, because its address is not knowable when it is built. <strong>Same word, same mechanism, completely different cost, and the reason is who chooses the load address.</strong></p>
                <p>One more measured detail. <strong>The <code>.data</code> relocation is <code>R_X86_64_64</code> in all three builds</strong> &mdash; a 64-bit absolute reference to the string literal, unchanged by <code>-fPIC</code>. That looks like an oversight and is not. The 64-bit field <em>can hold any address on any platform</em>, so a PIC library still links correctly if loaded at an address above 4 GB; the only thing that would break is a load <em>below</em> the link address, and that cannot happen for a library the linker cannot relocate. <strong>On a 64-bit target, an absolute 64-bit field is already position-independent in practice</strong>, which is why the cost of PIC shows up in the 32-bit code references and not in the data.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>What a code generator actually has to decide, and why the decision is not optional. The choice is per-reference, not per-file:</p>
                <div class="formula">
  a code generator emitting a reference to symbol S
  from instruction at address P must choose:

    1. a CALL, to a function:
         if S is defined in this object -> PC-relative.
             Already independent. No cost.
         if S is not defined here   -> PLT-relative.
             The linker may need a PLT entry. No cost.

    2. a DATA reference, to an object:
         for a PIE executable -> PC-relative.
             The data travels with the code. No cost.
         for a shared library -> GOT-relative.
             One indirection. THAT is the price of PIC.

    3. a reference within a section, to a
       local or a section symbol:
         PC-relative, always. Never needs the GOT.
</div>
                <p><strong>Row 3 is the one that makes PIC cheap, and it is easy to miss.</strong> References to something inside the same object &mdash; a static variable, a string literal's own section, a local label &mdash; are always relative, because the linker controls both ends and can compute the distance exactly. <strong>The GOT is only needed for references that leave the object.</strong> That is why a typical library's <code>.text</code> has a handful of GOT relocations rather than hundreds, and it means the real cost of PIC scales with the library's external surface rather than its size.</p>
                <p>And the failure mode, which is worth stating because it is silent in a way that matters. <strong>A non-PIC object linked into a shared library works, and then breaks the moment the library is loaded somewhere inconvenient.</strong> The absolute addresses were baked in at link time; if the loader honours them, fine; if it cannot, the library is rejected or, worse, mapped and the data references point into whatever happens to be there. <strong>Nothing in the object file records that it was built non-PIC</strong> &mdash; there is no flag, no bit, no attribute. The only evidence is the <em>absence</em> of GOT relocations, which is exactly the kind of fact a file does not defend.</p>
                <div class="callout callout-warn">
                    <strong>So the same rule from the COMMON concept applies, and it is worth naming as a general property of link-time facts.</strong> Whether an object is position-independent is not recorded &mdash; it is <em>inferred</em> from the relocation types present, and the inference is a negative one. A tool that wants to know must look for the <em>presence</em> of an absolute relocation, because absence is the signal. That is much harder to check than reading a flag, it cannot be cross-validated against a second field, and it fails silently when a producer changes its defaults. <strong>Compare the ELF <code>e_type</code> field, which records "relocatable" explicitly, and compare a hypothetical format that recorded "position independent: yes".</strong> Neither exists, in either format, and the reason is the same in both: position independence was a compiler flag long before it was a file-format concern, so it never got a field.
                </div>
                <p>The connection to the previous concept is exact and worth stating in one line: <strong>the <code>TYPE</code> flag and PIC are the same fact seen from two sides.</strong> An absolute relocation is flagged <code>TYPE</code> because the value must fit its field &mdash; and in a 32-bit field, a position-independent load address may not fit. <strong>That is why a 32-bit absolute relocation in a PIE is not merely inelegant but fatal</strong>, and it is why <a href="/courses/pe">hardened-binary checks</a> look for the presence of those relocations as evidence that a binary is not position-independent. A flag in a relocation table, a compiler command-line option, and a security property are the same thing at three layers.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ clang -target x86_64-pc-linux-gnu -O1 -c -o a.o demo.c
$ clang -target x86_64-pc-linux-gnu -O1 -fPIC -c -o b.o demo.c
$ llvm-objdump-21 -r a.o
$ llvm-objdump-21 -r b.o</code></pre>
                <ul>
                    <li><strong>Reproduce the three-build table.</strong> No flag, <code>-fPIC</code>, <code>-fPIE</code>, and diff the relocation output. <strong>Then assert that <code>-fPIE</code> and no-flag are byte-identical</strong> and check whether the files themselves are identical too &mdash; which they may not be, because <code>-fPIE</code> can still change codegen without changing relocations, and finding out which is a good exercise.</li>
                    <li><strong>Explain the offset shift by disassembling both.</strong> <code>llvm-objdump-21 -d</code> on <code>a.o</code> and <code>b.o</code>, and find the instruction at <code>0x04</code> in each. <strong>Count the bytes.</strong> The GOT-relative form should be one byte longer because of the REX prefix, and seeing that prefix appear is the moment the concept stops being abstract.</li>
                    <li><strong>Prove row 3 &mdash; that internal references never need the GOT.</strong> Add a <code>static</code> variable and a string literal, compile with <code>-fPIC</code>, and check that neither produces a GOT relocation. <strong>Then add one <code>extern</code> variable and watch exactly one appear.</strong> The cost of PIC scaling with external surface rather than size is the practical lesson.</li>
                    <li><strong>Link a non-PIC object into a shared library and see what happens.</strong> <code>clang -shared</code> over a non-PIC object. <strong>Note whether it errors, warns, or succeeds</strong> &mdash; and if it succeeds, check whether the data references are absolute. Then write a tiny program that loads the library and reads the global. This is the failure mode the concept warns about, reproduced rather than described.</li>
                    <li><strong>Count GOT relocations against library size.</strong> Compile something large with <code>-fPIC</code> and count them. <strong>Compare against the number of <em>distinct external</em> symbols it references</strong>, not against its line count. The ratio is the interesting number and it is usually far smaller than expected.</li>
                    <li><strong>Check the AArch64 case.</strong> <code>clang -target aarch64-linux-gnu -fPIC -c</code> and count relocations. <strong>Expect roughly double, from the ADRP/LO12 pairing, plus a GOT base register to set up</strong> &mdash; and then work out which register holds the GOT pointer and which relocation set it. That is where <code>obj-arch-table</code> becomes necessary, and seeing the need is the right way to meet it.</li>
                    <li><strong>Look for a way to record PIC-ness, and argue whether it should exist.</strong> Search the three formats' headers for anything resembling a position-independence flag. <strong>There is nothing</strong>, and the reason is historical: the flag predates the file format. Then write the two-byte field you would add and list what could go wrong with it &mdash; which is a design exercise with no clean answer, and is the most useful thing you can do to internalise why the format is shaped this way.</li>
                </ul>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: the same source compiled with <code>-fPIE</code> and with no flag at all produces byte-identical relocation sets, while <code>-fPIC</code> changes three of the eight. Under <code>-fPIC</code> the relocation at <code>0x04</code> moves to <code>0x05</code>. Why does <code>-fPIE</code> cost nothing, why does changing the relocation type move a <em>later</em> relocation's offset, and what is the practical consequence of the first fact for a tool that wants to know whether an object is position independent?</p>
                <div class="quiz" id="quiz-obj-pic-1">
                    <button class="quiz-option" data-correct="true" data-explain="Three separate reasons, and the third is the one with teeth. On cost: a PIE is the first thing the loader maps and may be placed near its link address, so its data travels with its code and a distance from here to a global is already correct without any indirection. A shared library's address is chosen by whoever loads it, on a machine nobody pictured at build time, so its data can end up anywhere and a distance is not enough; it needs the address of a GOT slot the loader fills in. That is why only the library pays, and the cost is one memory indirection per external global access. On the offset shift: the GOT-relative encoding requires a REX prefix byte that the plain RIP-relative form does not, so the instruction is one byte longer, and every subsequent instruction in the section moves with it, taking its relocations along. The relocation did not move; the code it points into did. On the consequence: nothing in the file records position independence, so a tool must infer it from the presence of an absolute relocation, because the absence is the signal. That is a negative inference, it cannot be cross-checked against a second field, and it fails silently when a producer changes its defaults. The general habit is to be suspicious of any property a format does not record, and to ask what a tool is forced to guess." onclick="checkQuiz('obj-pic-1', this)">A PIE is the first thing mapped and can sit near its link address, so its data moves with its code and PC-relative distances are already correct &mdash; only a shared library, whose address is chosen by the loader, needs the GOT. The offset shifts because <code>REX_GOTPCRELX</code> needs a REX prefix, making the instruction one byte longer and sliding everything after it. And nothing records PIC-ness, so a tool must infer it from the <em>presence</em> of an absolute relocation</button>
                    <button class="quiz-option" data-correct="false" data-explain="The offset shift is right, and the other two answers are the two common misconceptions this concept exists to correct. On the cost, a PIE and a shared library both describe code that must be loadable at an address not chosen at build time, and treating one as exempt inverts the distinction: a PIE's data travels with its code precisely because the loader is free to place the whole image together, while a library's data is addressed by other code that may be mapped anywhere, so the indirection is what makes that safe. Saying the PIE does not need it is only true in the narrow sense that its own internal distances are already correct, which is not the same as saying it needs nothing. On the consequence, the proposed fix is the opposite of the fact: nothing in the file records it, which is precisely why a tool has to infer it from the relocation types, and inferring from absence is the fragile option rather than a robust one. The only part of this answer that survives is the REX prefix explanation, and that one is right." onclick="checkQuiz('obj-pic-1', this)">A PIE is exempt because the loader guarantees the whole image moves as a unit, so its data and code stay together, and the offset moves because the GOT form uses a longer instruction. A tool can read the relocation types directly to determine PIC-ness, so nothing is guessed</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>You are writing a build tool that must decide whether each object in a project is safe to put into a shared library. Your current check reads <code>e_type</code> from the ELF header and accepts anything that is <code>ET_REL</code>. It passes a library that then fails to load on a machine where the loader cannot honour its absolute addresses, and it has no way to predict which objects will cause that. What is the check the object file actually supports, what is its fundamental weakness, and what is the practical mitigation given that you cannot change the producers?</p>
                <div class="quiz" id="quiz-obj-pic-2">
                    <button class="quiz-option" data-correct="true" data-explain="The check the format actually supports is the presence of an absolute relocation, specifically one whose TYPE flag says the value must fit its field, and in practice the 32-bit family on x86-64. A 64-bit absolute field is effectively position independent because it can hold any address, so the thing to look for is the narrow ones. Its fundamental weakness is that it is a negative inference in a file that does not record the property: absence of evidence rather than evidence of absence, and a producer that emits a non-PIC object with no absolute relocations at all is indistinguishable from a PIC one, which is exactly the case that fails quietly. You also cannot cross-validate it against a second field, because there is no second field. The practical mitigation given fixed producers is to stop inferring and start constraining: check the build flags, because the compiler knows and the object does not, and fail the build when an object destined for a shared library was not built with -fPIC. That inverts the inference into an assertion made at the point where the information actually exists. The alternative mitigation, which is also worth knowing, is to link the object into the library and let the linker refuse it, since modern linkers do reject absolute relocations in a shared object on many targets; that catches the case but reports it later and with a worse message." onclick="checkQuiz('obj-pic-2', this)">Check for the presence of a 32-bit absolute relocation &mdash; the <code>TYPE</code>-flagged family &mdash; since that is the only evidence the file carries. Its weakness is that it is a negative inference from a property the format does not record, so a non-PIC object with no absolute relocations looks identical to a PIC one. Mitigate by checking the build flags instead: the compiler knows, the object does not</button>
                    <button class="quiz-option" data-correct="false" data-explain="This sounds more robust than the reality and is less safe, because it trusts a field to mean something it does not mean. e_type records whether the file is relocatable, which tells you the file is an object and nothing about how its references are encoded. Every object in the project is ET_REL, so the check passes uniformly and distinguishes nothing; that is why the tool has no signal at all today rather than a weak one. The stronger version of the same error is to look for a PIC flag in the section or symbol tables, and there is no such flag in ELF, COFF or Mach-O for the reason the concept gives: the compiler option predates the file format and nobody backfilled a field for it. Searching the headers will confirm the absence, and that confirmation is the useful output of the exercise. The check that works is the negative one, and the mitigation that makes it safe is to assert the property at build time where the compiler actually knows it, rather than trying to recover it from a file that does not carry it." onclick="checkQuiz('obj-pic-2', this)">Read the <code>e_flags</code> field of the ELF header, which records the position-independence mode directly, and treat a non-PIC value as a hard error. It is robust because it is an explicit assertion rather than an inference, and no mitigation is needed</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: when a property is not recorded, stop inferring it and constrain it at the point where it <em>is</em> known. A negative inference from a file is a guess; a build-time assertion is a fact.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>This concept is where the previous one's table stops being a reference. <a href="/courses/obj/lessons/obj-reloc-tables">The Object Relocation Sets</a> gave 44 and 147 classified entries and said the choice among them <em>is</em> what position independence means; this is that claim paid off. <strong>Three entries changed and the reason is a data-structure decision &mdash; one table the loader can rewrite, versus distances that survive translation.</strong> And the <code>TYPE</code> flag's overflow check, which looked like a safety measure, turns out to be the mechanism by which a position-independent load is refused when a 32-bit field cannot hold it.</p>
                <p>The GOT connects to the section-table work in a way that is easy to miss. <strong>The GOT is a section, allocated by the linker, containing pointers the loader rewrites</strong> &mdash; and that is the same pattern as the <code>.plt</code> stubs, the <code>.dynamic</code> table and the <code>.got.plt</code> array that <a href="/courses/obj/lessons/obj-no-segments">the segments concept</a> found appearing only in the linked output. <strong>The linker generates structures that no compiler emitted, and the GOT is the one PIC specifically requires.</strong> Compare the non-PIC build, which needs a <code>.plt</code> for its calls and no <code>.got</code> for its data &mdash; the file's contents differ by a whole section depending on this concept's subject.</p>
                <p>The <code>REX</code> prefix is a small, instructive anomaly and it connects to instruction encodings directly. <strong>An encoding can be genuinely ambiguous, and a format's answer is to add a byte that says which reading is intended.</strong> That is a different answer from the one ELF gives everywhere else &mdash; a separate relocation type, a separate flag &mdash; and it exists because of one opcode-reuse accident in 1980s x86. <strong>It is the clearest example in the course of a format carrying a historical scar, and it is a reminder that reading a relocation type's name tells you very little about its mechanics.</strong> A linker author has to read the specification for that one rather than generalising from the other 43.</p>
                <p>On the security side, the connection is direct and it is the same thread the <a href="/courses/obj/lessons/obj-reloc-tables">relocation tables</a> concept pulled. <strong>A non-PIE executable has fixed, predictable addresses, which is the precondition for a large class of exploitation technique.</strong> That is why &ldquo;is this binary position independent&rdquo; is a question distributions, auditors and hardening tools ask &mdash; and it is answered by looking for exactly the absolute relocations this concept taught you to recognise. <strong>The relocation table is simultaneously a linking concern, a compiler flag, and a security property</strong>, and understanding why is the difference between knowing a flag exists and knowing what it costs.</p>
                <p>And the &ldquo;not recorded&rdquo; theme is the last connection, because it is the course's running argument rather than this concept's. <strong>Object files do not record whether they are position independent, whether they use COMMON, or which compiler produced them</strong> &mdash; yet all three are facts a tool needs. The format's discipline is to record only what a <em>linker</em> needs, and to leave everything else to be inferred from the structure. That is a coherent design and it has a cost, and the cost is that every consumer beyond the linker has to guess. The <a href="/courses/elf">ELF course's</a> discussion of <code>.gnu.linkonce</code> and section groups is the same trade in the opposite direction &mdash; an explicit mechanism for recording a merge decision &mdash; and comparing the two is the clearest way to understand where a format's priorities are.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/obj/lessons/obj-reloc-tables">Previous: The Object Relocation Sets</a></span>
                <span><a href="/courses/obj/lessons/obj-comdat-group">Next: COMDAT, GROUP, linkonce</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
