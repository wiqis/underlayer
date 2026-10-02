// Object Files — Module 3: The Fixup
// Concept: the per-architecture relocation tables, and why forty-four types on
// one architecture is a classification rather than a list.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_obj_reloc_tables() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Object Relocation Sets — Underlayer")
    page.appendTitle(&title)

    render_lesson_nav(&mut page)
    render_lesson_css(&mut page)

    #html {
        <div class="lesson obj-lesson">
            <a href="/courses/obj" class="back-link">Back to course</a>
            <h1>The Object Relocation Sets</h1>
            <div class="lesson-meta">22 min &middot; Module 3: The Fixup &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p><a href="/courses/obj/lessons/obj-the-hole">The second concept</a> introduced a relocation record and worked through one of them. It did not tell you how many there are, and the honest answer is that the number is the first thing that makes the mechanism look impractical:</p>
                <div class="hex-dump">
                    <pre>  X86-64     44 relocation types
  AArch64   147 for LP64, plus 86 more for the ILP32 ABI = 233
</pre>
                </div>
                <p>Forty-four sounds like a lot to implement. It is not, and <strong>the reason it is not is the single most useful thing in this concept: the table is not a list, it is a classification.</strong> Every entry carries a small set of property flags, and an implementation switches on the flags rather than on the name. Forty-four entries collapse to about seven distinct behaviours.</p>
                <p>This matters for the mission directly. A learner building a linker has to face this table eventually, and the difference between "147 cases to memorise" and "seven properties to combine" is the difference between a course that can be finished and one that cannot. <strong>So this concept is about the structure of the table, not its contents</strong> &mdash; and the contents are enumerated anyway, because the mission says teach everything, with a clear statement of which parts a linker must implement and which it can defer.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>First, where the authoritative list actually comes from, because that is a practical question with a specific answer. Two sources, and they must agree:</p>
                <div class="formula">
  SOURCE 1:  /usr/include/elf.h
            the system C header. 44 R_X86_64_ names.
            Plain enum, no metadata. Names only.

  SOURCE 2:  llvm/BinaryFormat/ELFRelocs/X86_64.def
            llvm/BinaryFormat/ELFRelocs/AArch64.def
            A machine-checked table where each entry carries
            bit flags, and the code generator READS those
            flags. This is the source that tells you what
            each type MEANS.
</div>
                <p>That asymmetry is worth dwelling on, because it is a general lesson about where format truth lives. <strong><code>elf.h</code> tells you the names and numbers. The <code>.def</code> file tells you the semantics.</strong> And the reason is that the names are what a programmer writes while the flags are what an <em>implementation</em> needs &mdash; so LLVM's table is shaped by the requirement that a code generator be able to switch on a property rather than match 147 strings.</p>
                <p>The flags, decoded, and this is the whole concept in one table:</p>
                <div class="hex-dump">
                    <pre>  flag  bit  name       what it tells an implementation
  ----  ---  ---------  ------------------------------------------
  REL   0x1  Relative   divide by the field width: the value
                         already stored in the bytes is an
                         offset, not a final value
  SYM   0x2  Symbolic   the result is a plain symbol address,
                         NOT divided by anything
  PC    0x4  PCRelative subtract the patch address
  TYPE  0x8  Type       the field holds an ADDRESS, so the
                         result must fit in the field or the
                         link must fail
  SIZE  0x10 Size        the relocation needs TWICE the field
                         space, because a second quantity has
                         to be encoded alongside
  TLS   0x20 TLS         the symbol is thread-local
  IREL  0x40 Indirect    the value is a resolver function's
                         address, patched at load time
</pre>
                </div>
                <p><strong>Every one of those seven is a thing a linker has to decide, and the table exists so the linker does not have to decide it by matching names.</strong> That is the whole design. A linker implements <code>switch (flags &amp; PC)</code> and <code>switch (flags &amp; TYPE)</code> and <code>switch (flags &amp; REL)</code>, and the forty-four names never appear in the code.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>The counts, and then the twelve entries a linker implements first, with their flags decoded from the <code>.def</code> file on this machine:</p>
                <div class="hex-dump">
                    <pre>  ARCH     TOTAL   PC-RELATIVE   TLS
  ------  ------  -----------  ----
  X86-64      44           18    18
  AArch64     147           71    53   (LP64)
  AArch64      86            -     -   (P32 / ILP32, separate ABI)

  AArch64's 233 is two ABIs in one table, which is worth
  knowing before you conclude anything from the number.
</pre>
                </div>
                <p>And the twelve that matter first, on x86-64:</p>
                <div class="hex-dump">
                    <pre>  TYPE                          NUM  FLAGS        what it does
  ---------------------------  ---  -----------  ---------------------
  R_X86_64_NONE                   0  none          a placeholder; do nothing
  R_X86_64_64                     1  REL           S + A, 8-byte field
  R_X86_64_PC32                   2  SYM           S + A - P, 4-byte
  R_X86_64_GOT32                  3  SYM+REL       offset from the GOT
  R_X86_64_PLT32                  4  PC            PC-relative, and
                                                  a call: may need a PLT
  R_X86_64_GOTPCREL               9  TYPE+REL      address of a GOT slot
  R_X86_64_32                    16  SIZE          absolute, must FIT
  R_X86_64_32S                   17  SIZE+REL      signed absolute
  R_X86_64_16                    18  SIZE+SYM      16-bit absolute
  R_X86_64_8                     20  SIZE+PC       8-bit PC-relative
  R_X86_64_PC64                  36  TLS+PC        PC-relative, 8 bytes
  R_X86_64_GOTOFF64              37  TLS+PC+REL    offset from the GOT
</pre>
                </div>
                <p>Three things in that table are worth more than the rest.</p>
                <h3>R_X86_64_PC32 is flagged SYM, not PC</h3>
                <p>The name says <em>PC</em>-32 and the flag says <code>SYM</code>. That looks like an error and it is not &mdash; the flags are LLVM's <em>implementation</em> classification, and they do not attempt to restate the mnemonic. <strong>The number after the mnemonic is the field width; the flags are the behaviour.</strong> Two different facts, two different places, and confusing them is the most common way to misread this table.</p>
                <h3>PLT32 carries the PC flag and PC32 does not</h3>
                <p>This is the closure of the finding from <a href="/courses/obj/lessons/obj-the-hole">the second concept</a>, and it is satisfying. That concept measured that <code>R_X86_64_PC32</code> and <code>R_X86_64_PLT32</code> perform <em>identical arithmetic</em>, with the only difference being a hint that a PLT entry might be needed. Here is where the difference lives: <strong><code>PLT32</code> is flagged <code>PC</code> and <code>PC32</code> is not.</strong></p>
                <p>So the hint is not a separate boolean. <strong>It is the <code>PC</code> flag itself, and the reason is that on x86-64 a call is genuinely PC-relative in a way a data reference is not</strong> &mdash; which is also why <code>PLT32</code> is the type that needs a PLT and <code>PC32</code> is not. The mnemonic says <code>PC</code> and the flag says <code>SYM</code> because the name describes the field and the flag describes the relocation. <strong>Read both, and you have the whole type.</strong></p>
                <h3>The SIZE flag on AArch64, and what it is really about</h3>
                <p>Now the one that explains the AArch64 doubling, and it is the best evidence in the whole course that the pairing is a real constraint rather than a convention:</p>
                <div class="hex-dump">
                    <pre>  R_AARCH64_ADR_PREL_PG_HI21          275  SIZE+SYM+REL
  R_AARCH64_ADR_PREL_PG_HI21_NC       276  SIZE+PC
  R_AARCH64_ADD_ABS_LO12_NC           277  SIZE+PC+REL
  R_AARCH64_LDST32_ABS_LO12_NC        285  SIZE+TYPE+PC+REL
  R_AARCH64_LDST64_ABS_LO12_NC        286  SIZE+TYPE+PC+SYM
  R_AARCH64_CALL26                   283  SIZE+TYPE+SYM+REL
  R_AARCH64_JUMP26                    282  SIZE+TYPE+SYM
  R_AARCH64_ADR_GOT_PAGE              311  TLS+SIZE+PC+SYM+REL
  R_AARCH64_LD64_GOTOFF_LO15          310  TLS+SIZE+PC+SYM
</pre>
                </div>
                <p><strong>Every single AArch64 relocation that participates in an ADRP/LO12 pair carries the <code>SIZE</code> flag.</strong> And the flag's meaning is "this relocation needs twice the field space, because a second quantity has to be encoded alongside."</p>
                <p>That is the machine-checked form of the finding from the second concept. <strong>One reference to an address on AArch64 needs two relocations because the page delta and the page offset are two separate fields, and LLVM flags both halves as needing extra space precisely because they will have to be combined with their partner.</strong> The pairing is not a convention a code generator and a linker agree on by documentation; it is recorded in a bit that says <em>this one is not independent</em>.</p>
                <div class="callout callout-warn">
                    <strong>And here is the trap a linker author must design around.</strong> A linker that treats relocations independently &mdash; that reads each record, computes, writes, moves on &mdash; produces a binary where half the AArch64 relocations have been computed against an incomplete expression. <strong>It links cleanly, because nothing in the object file is malformed.</strong> It faults at run time, on the first access to any global through a pointer, and only on AArch64. The <code>SIZE</code> flag is the format telling you that independence is the wrong model, and it is telling you in the only channel available: a bit in a table.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>What a linker actually has to implement, which is a much shorter list than either table, and it is worth writing down because the gap between "147 types" and "nine cases" is the difference between a feasible and an infeasible project:</p>
                <div class="formula">
  A LINKER MUST HANDLE, on any architecture:

    1. absolute            S + A                into an address field
    2. PC-relative         S + A - P            into a disp field
    3. GOT-relative        S + A - GOT          for -fPIC data
    4. PLT/call            PC-relative, + PLT    for calls
    5. overflow check      the TYPE flag: if the value does
                           not fit the field, FAIL THE LINK
                           rather than truncate
    6. paired entries      the SIZE flag: combine with a
                           partner before writing
    7. TLS                 the TLS flag: resolve through
                           the thread-local block
    8. IRELATIVE           the IREL flag: a resolver address
                           patched at load time
    9. NONE                the no-op, which must be
                           recognised and skipped

  EVERYTHING ELSE in the 44 or 147 is a WIDTH or a SIGN
  VARIANT of one of these.  R_X86_64_8, _16, _32, _64 and
  _32S are the same case with a different field size.
                </div>
                <p><strong>Which is the honest answer to "how do I implement 147 relocations", and the answer is: you implement nine and derive the rest.</strong> Step 5 deserves emphasis because it is the one a beginner forgets and the one that produces the worst class of bug: <strong>the <code>TYPE</code> flag exists because a 32-bit absolute relocation to an address outside 32 bits is not a truncation, it is a failure.</strong> A linker that silently truncates produces a binary that runs and reads the wrong memory; a linker that fails produces an error you can act on. <strong>Every <code>SIZE</code>-flagged absolute entry in the table &mdash; <code>R_X86_64_32</code>, <code>R_X86_64_16</code>, <code>R_X86_64_8</code> &mdash; is a place where that check is mandatory</strong>, and they are flagged <code>SIZE</code> precisely so the check cannot be forgotten.</p>
                <p>Where the table is genuinely large is TLS, and the numbers explain why: 18 of x86-64's 44 entries and 53 of AArch64's 147 are TLS. <strong>Thread-local storage is not one relocation, it is a family of about a dozen per architecture</strong>, because a thread-local address has several components &mdash; the thread pointer, an offset into the TLS block, a module offset, a symbol offset &mdash; and each instruction form combines a different subset. Compare that with the four non-TLS absolute and PC-relative cases. <strong>Relocation table size tracks instruction-set complexity in the area being addressed, not the number of addressing modes.</strong></p>
                <p>Which is why "read the waste to read the history" has a limit worth stating. A 44-entry table is not 44 design decisions; it is about nine decisions expanded by field width, by sign, and by TLS. <strong>And the TLS entries are the newest &mdash; they accumulate as thread-local models were standardised across architectures, which is the same pattern as the JVM attribute mechanism and the ELF section types.</strong> A format's table is a growth record, and the growth clusters where new capabilities arrived rather than spreading evenly.</p>
                <p>Finally, the question a learner will ask and the answer is worth having ready: <strong>which of these are object-only?</strong> The answer is that the table is shared. The same <code>R_X86_64_PC32</code> appears in a relocatable object and in a linked executable, and <code>R_X86_64_32</code> is common in objects and forbidden in position-independent executables &mdash; where a build with <code>-fPIE</code> has no absolute relocations at all, and the presence of one is what <a href="/courses/pe">control flow hardening</a> checks for. <strong>So the table is not partitioned by file type; the <em>compiler's choices</em> determine which subset appears, and a linker must handle the union.</strong> That is a design fact worth holding, because it means a linker cannot assume it will only ever see the narrow set, and a PIE-aware linker has to reject the wide one deliberately rather than by omission.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ grep -c R_X86_64_ /usr/include/elf.h
$ grep -cE '^ELF_RELOC' /usr/lib/llvm-21/include/llvm/BinaryFormat/ELFRelocs/AArch64.def</code></pre>
                <ul>
                    <li><strong>Get both authoritative lists and count them.</strong> 44 from <code>elf.h</code>, 233 from <code>AArch64.def</code> &mdash; then find the 86 <code>R_AARCH64_P32_</code> entries and subtract them to get 147 for the LP64 ABI. <strong>The headline number is 233 and the useful number is 147, and the difference is a second ABI hiding in the same table.</strong> Always check for that before drawing a conclusion from a count.</li>
                    <li><strong>Cross-check the two sources against each other.</strong> Extract the <code>R_X86_64_</code> names from <code>elf.h</code> and from <code>X86_64.def</code> and diff them. <strong>Any name in one and not the other is a version skew</strong>, and finding one is how you learn that the two files can disagree &mdash; which is exactly the situation the mission's verification rule exists for.</li>
                    <li><strong>Sort the table by flags instead of by name.</strong> Group all 44 x86-64 entries by their flag combination and count the groups. <strong>Then implement one case per group</strong> and see whether your linker handles the whole table. This is the exercise that turns "147 relocations" from a wall into a list of about nine, and it takes twenty minutes.</li>
                    <li><strong>Find every <code>SIZE</code>-flagged entry and check whether it pairs.</strong> On AArch64, list them and look for the <code>ADR_PREL_PG_HI21</code>/<code>LO12_NC</code> pattern. <strong>Then compile a file that takes the address of a global on AArch64 and confirm you get two records for one reference</strong> &mdash; the concept's central claim, reproduced from scratch.</li>
                    <li><strong>Test the overflow check with a real link.</strong> Write a function that takes the address of a large object into a 4-byte absolute field, compile with <code>-fno-pic</code>, and try to link it into a PIE. <strong>The <code>TYPE</code> flag exists so this fails loudly, and watching it fail is worth more than reading that it would.</strong> Then find which flag on which entry made the decision.</li>
                    <li><strong>Build a PIE and count its absolute relocations.</strong> <code>readelf -r</code> on a <code>-fPIE</code> build: expect none of the <code>_32</code> family. <strong>Then build with <code>-fno-pic</code> and count them again.</strong> The difference is the entire practical meaning of the PC-relative and GOT-relative entries, measured rather than argued.</li>
                    <li><strong>Answer the "what can I defer" question honestly.</strong> Take the nine cases the concept lists and mark which your target's toolchain can actually emit today. <strong>Almost every object file you will ever read uses four or five of them</strong> &mdash; the rest exist for toolchains, ABIs and hand-written assembly you may never encounter. Knowing which are load-bearing for your users is the difference between a linker that is finished and one that is not.</li>
                </ul>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: an AArch64 object has <code>R_AARCH64_ADR_PREL_PG_HI21_NC</code> at offset 0 and <code>R_AARCH64_LDST32_ABS_LO12_NC</code> at offset 4, for one reference to a global. What does the <code>SIZE</code> flag on both of them tell a linker, what happens if the linker processes them independently, and why is the failure a run-time fault rather than a link error?</p>
                <div class="quiz" id="quiz-obj-reloc-tables-1">
                    <button class="quiz-option" data-correct="true" data-explain="The SIZE flag says the relocation is not independent: it needs twice the field space because a second quantity must be encoded alongside it, which on AArch64 means the page delta in the ADRP half has to be combined with the 12-bit page offset in the paired LO12 half. A linker that processes them independently computes each against an incomplete expression and writes both, and the result is a register or memory operand holding a page number with an offset that does not belong to it. The reason this is a run-time fault rather than a link error is the crucial part and it is a property of the file, not of the linker. Nothing in the object is malformed. Each record is structurally valid, its offset points at a real field, its symbol index is valid, and its type is one the linker fully understands. The pairing is a relationship between two records, and the file has no way to mark a relationship as broken, because nothing is broken. Compare that with the TYPE flag, where the value genuinely does not fit and the linker is expected to refuse: there the format gives the linker a way to know it cannot succeed. Here it gives the linker a way to know it must not try alone, and the only failure mode available is the wrong answer. That is why SIZE exists as a distinct flag from TYPE, and it is why a linker must treat the relocation list as a graph rather than a set." onclick="checkQuiz('obj-reloc-tables-1', this)">The <code>SIZE</code> flag means each half is not independent &mdash; the ADRP page delta and the LO12 page offset have to be combined, which needs extra field space. Processing them independently writes both against incomplete expressions. It faults at run time because nothing in the file is malformed: each record is valid in isolation, the pairing is a relationship between two records that the file cannot mark as violated, and there is no value anywhere that fails to fit</button>
                    <button class="quiz-option" data-correct="false" data-explain="The conclusion about independence is right, and the mechanism attributed to the SIZE flag is wrong in a way that points the implementation at the wrong bit. SIZE does not mean the value will not fit the field. That is what the TYPE flag means, and the distinction is exactly why both flags exist. SIZE means the relocation needs more space than its field nominally provides, because a second quantity must be packed alongside the first -- on AArch64, because the ADRP half encodes a page delta that has to be reconciled with the paired LO12 half's 12-bit offset. Reading SIZE as an overflow check sends a linker to validate magnitudes that are perfectly legal, which means it will reject valid objects; and worse, it will not implement the actual requirement, which is to pair the records before computing either. The rest of this answer is worth keeping, because the run-time-not-link-time argument is correct and is the most important part: the pairing is a relationship between records that the file has no way to mark as violated, so there is no error for a linker to raise. Get the flag's meaning right, though, and the fix is a graph walk over the relocation list rather than a range check." onclick="checkQuiz('obj-reloc-tables-1', this)">The <code>SIZE</code> flag means the computed value will not fit in the field, so the linker must fail the link rather than truncate. It produces a run-time fault rather than a link error because AArch64's linker chooses to defer that check, leaving the overflow to be discovered by the CPU</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>You are writing the relocation-application pass of a linker. It reads each record, computes the value from the type's flags, and writes it, in list order, with no interaction between records. It is correct on every x86-64 object you have tested. On AArch64 it links without error and every pointer to a global is wrong, while calls to functions are correct. The <code>SIZE</code> flag is right there in the table and your code ignores it. What is the smallest change that makes the pass correct, and why is a per-record fix impossible rather than merely tedious?</p>
                <div class="quiz" id="quiz-obj-reloc-tables-2">
                    <button class="quiz-option" data-correct="true" data-explain="The smallest correct change is to stop treating the relocation list as a sequence and treat it as a set to be grouped before any arithmetic happens. Concretely: partition by section, then within a section group the SIZE-flagged entries by the field they pair on, and for each pair compute one combined value and write both fields from it. The reason a per-record fix is impossible rather than merely tedious is that the two records do not contain enough information individually to produce the right answer. The ADRP record knows the page delta and the LO12 record knows the low twelve bits, and the correct result depends on both -- the low bits are in the wrong place unless the page delta is known, and the page delta alone addresses a 2MB-aligned location, not the variable. There is no ordering in which processing them one at a time yields correct intermediate values, because the correct value is not a function of either record alone. That is a stronger statement than 'you need two passes': it says the information is distributed, so any implementation that computes per record is computing the wrong function. It also explains the observed symptom precisely. Calls are correct because JUMP26 and CALL26 have no partner, and pointers are wrong because the pair is processed as two independent half-expressions. The general habit is to check the flags that say a record is not independent before deciding your pass can be a single loop over records." onclick="checkQuiz('obj-reloc-tables-2', this)">Group the relocation list by section and by the partner the <code>SIZE</code> flag implies, compute each pair as one unit, and write both fields from the combined value. A per-record fix is impossible because neither record contains enough information alone &mdash; the correct value is not a function of either one &mdash; and it is why calls are right while pointers are wrong: <code>JUMP26</code> has no partner</button>
                    <button class="quiz-option" data-correct="false" data-explain=">The diagnosis is right and the implementation is not, and it is a tempting one because a two-pass approach sounds like it should work. Two passes over the list, computing in the first and writing in the second, still fails, because the problem is not when the write happens but that the value to write is not yet known. The ADRP record's correct final value depends on the page delta computed from the LO12 record's low bits and the two symbols involved, and no ordering of two passes over individual records makes that value available at either moment. You would need the second pass to recompute the first record's value from data it has already discarded, which means keeping it, which is the grouping the correct answer describes. The other part of this answer is right and worth keeping: calls are correct because they have no partner, and that observation is the diagnostic that distinguishes pairing from arithmetic. But the conclusion drawn from it, that ordering or a deferred write is enough, is the specific mistake to avoid, and it would produce a linker that is one pass short of correct." onclick="checkQuiz('obj-reloc-tables-2', this)">Process the relocation list twice: compute all the values first, then write them, so the AArch64 pairs are written after the whole section's arithmetic is settled. A per-record fix is impossible because the partner may appear later in the list, and the call-only correctness confirms it since calls have no partner to wait for</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: check the flags that say a record is <em>not independent</em> before deciding your pass can be a single loop over records. A record that needs a partner does not contain enough information to produce the right answer on its own &mdash; that is a stronger constraint than a missing ordering.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>This concept is the payoff for the one before it and the one after. <a href="/courses/obj/lessons/obj-the-hole">A Hole and a Record</a> established that a relocation answers four questions and that the third &mdash; the arithmetic &mdash; is a small per-architecture enum. <strong>This is that enum, and the finding is that it is not an enum at all: it is a set of independent properties.</strong> That reframing is worth more than the table itself, because it is the difference between memorising 147 names and implementing seven flags.</p>
                <p>The ELF course's <a href="/courses/elf/lessons/relocation-types">relocation types</a> concept teaches the same table for a single architecture, and the honest division of labour between the two is worth stating: that concept is the reference, and this one is the structure. <strong>You need this one to write a linker and the other one to read a manual.</strong> And the AArch64 pairing it explains is the same fact the <a href="/courses/obj/lessons/obj-the-hole">second concept</a> measured as "eight records where x86-64 needs four" &mdash; here it is a bit in a table rather than an observation about a file, which is the stronger form of the same claim.</p>
                <p>The <code>TYPE</code> flag and the overflow check connect straight to the collapsed <em>Relocations, PIC and PIE</em> course, and to a security consequence rather than a correctness one. <strong>A 32-bit absolute relocation is incompatible with position independence</strong>, because the whole point of PIE is that the load address is not known until run time. So a PIE-aware toolchain must emit no absolute relocations, and <a href="/courses/pe">the hardened-executable checks</a> look for their presence as a signal that a binary is not position-independent. <strong>A flag in a relocation table is therefore also a security property, and that is the moment the format stops being about addresses and starts being about trust.</strong></p>
                <p>The TLS entries connect to the <a href="/courses/obj/lessons/obj-bss-common">COMMON concept</a> in an unexpected way, and it is worth naming. Both mechanisms exist because <strong>C has a declaration whose storage is decided somewhere other than where it is written</strong>: COMMON because the definition might be elsewhere, TLS because the storage is per-thread and therefore cannot be assigned at link time at all. One is resolved by merging and the other by indirection through a thread pointer, <strong>but both are the same underlying problem &mdash; a symbol whose address is not a constant, and therefore cannot be the answer to any relocation's arithmetic.</strong> A linker that implements COMMON and TLS is implementing the same idea twice, in two vocabularies.</p>
                <p>And the growth story is the format-history story again, at a larger scale. <strong>18 of x86-64's 44 entries and 53 of AArch64's 147 are TLS</strong> &mdash; a single capability, arriving after the core table was designed, and expanding it by a factor of three. That is precisely the pattern of the JVM's attribute mechanism, of ELF's section types, and of the mission's own observation that formats grow additively. <strong>A relocation table is a record of what the instruction set ended up needing, not of what anyone planned</strong>, and reading the distribution tells you which capabilities were hard to retrofit. On both architectures the answer is thread-local storage, which is a genuinely useful thing to know and is not written down anywhere in the specifications.</p>
                <p>Next: position independence, which is where this table stops being a reference and becomes a design tool &mdash; because choosing which of these types to emit <em>is</em> what position independence is.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/obj/lessons/obj-addends">Previous: The Addend Lives in the Bytes</a></span>
                <span><a href="/courses/obj/lessons/obj-pic">Next: Position Independence</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
