// COFF Course — Module 3: Containers and Variants
// Concept: bigobj — the header that relocates its own fields.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_coff_bigobj() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("bigobj — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson coff-lesson">
            <a href="/courses/coff" class="back-link">Back to course</a>
            <h1>bigobj</h1>
            <div class="lesson-meta">20 min &middot; Module 3: Containers and Variants &middot; Structures</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Two fields in the 20-byte header are 16 bits wide: <code>NumberOfSections</code> and <code>NumberOfSymbols</code>. 65,535 of each sounds like plenty until you meet a machine-generated translation unit, where a single C++ header with templates can emit a hundred thousand COMDAT sections. At that point a compiler has a choice: emit a file it cannot describe, or switch formats.</p>
                <p><code>bigobj</code> is that second format, and its central trick is the reason it is worth a whole concept. <strong>It does not widen the fields. It moves them.</strong> Every offset after <code>NumberOfSections</code> changes, which means a parser written for the classic layout does not fail on a bigobj &mdash; it silently describes a different file.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Two headers, side by side. This is the whole concept:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Classic (20 bytes)</th><th scope="col">bigobj (56 bytes)</th></tr>
                    </thead>
                    <tbody>
                        <tr><td><code>Machine</code> (2)</td><td><code>Sig1</code> = 0x0000 (2)</td></tr>
                        <tr><td><code>NumberOfSections</code> (2)</td><td><code>Sig2</code> = 0xFFFF (2)</td></tr>
                        <tr><td rowspan="6" style="vertical-align:top"><code>TimeDateStamp</code> (4)<br><code>PointerToSymbolTable</code> (4)<br><code>NumberOfSymbols</code> (4)<br><code>SizeOfOptionalHeader</code> (2)<br><code>Characteristics</code> (2)</td><td><code>Version</code> = 2 (2)</td></tr>
                        <tr><td><code>Machine</code> (2) &mdash; <strong>moved here</strong></td></tr>
                        <tr><td><code>TimeDateStamp</code> (4)</td></tr>
                        <tr><td><code>ClassID</code> (16) &mdash; a GUID, new</td></tr>
                        <tr><td><code>SizeOfData</code> (4), <code>Flags</code> (4), <code>MetaDataSize</code> (4), <code>MetaDataOffset</code> (4) &mdash; all new</td></tr>
                        <tr><td><code>NumberOfSections</code> (4) &mdash; <strong>widened to 32 bits</strong></td></tr>
                        <tr><td><code>PointerToSymbolTable</code> (4), <code>NumberOfSymbols</code> (4)</td></tr>
                    </tbody>
                </table>
                <p>Note what happened to <code>Machine</code>. In a classic object it is the <em>first</em> field, at offset 0. In a bigobj it is the <em>fourth</em>, at offset 6 &mdash; and offsets 0 and 2 now hold the signature. <code>SizeOfOptionalHeader</code> and <code>Characteristics</code> simply do not exist: there is no optional header in any object, so a variant that goes to the trouble of adding 36 bytes does not spend them on a field that is always zero.</p>
                <div class="callout callout-warn">
                    <strong>The section table moves too, and that is the visible consequence.</strong> In a classic object the section table starts at 20. In a bigobj it starts at <strong>56</strong>, because it follows the bigger header. And every file offset in the file &mdash; <code>PointerToRawData</code>, <code>PointerToRelocations</code>, <code>PointerToSymbolTable</code> &mdash; has to be adjusted by the 36 extra bytes, because all of that data was shifted up when the header grew. A bigobj is not the same file with wider integers; it is the same file with everything moved.
                </div>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <h3>First: does a compiler ever produce one?</h3>
                <p>This is the question worth answering before anything else, and the answer is measurable. Here is a translation unit with seventy thousand functions in it:</p>
                <pre><code>$ python3 -c "
lines = ['int f%d(int x)&#123;return x+%d;&#125;' % (i, i) for i in range(70000)]
open('huge.c','w').write('\n'.join(lines))
"
$ clang --target=x86_64-pc-windows-msvc -c huge.c -o huge.obj
$ file huge.obj
huge.obj: x86-64 COFF object file, not stripped, 7 sections,
          symbol offset=0x468072, 70017 symbols, ...
$ llvm-readobj --file-headers huge.obj
  Machine: IMAGE_FILE_MACHINE_AMD64 (0x8664)
  SectionCount: 7
  SymbolCount: 70017          &lt;- over the 65535 limit
  OptionalHeaderSize: 0</code></pre>
                <p><strong>70,017 symbols, comfortably past the 16-bit ceiling, and clang emitted a perfectly ordinary classic object.</strong> It did not switch. That is a fact about this toolchain rather than about the format, and it is worth stating plainly: the bigobj path is a <em>capability of the format</em> that this compiler does not exercise.</p>
                <h3>So: can a bigobj be verified at all?</h3>
                <p>Constructed one by hand, from the field list above. The naive approach &mdash; patch the first word to the signature, the second to the version &mdash; produces this:</p>
                <div class="hex-dump">
                    <pre>0000: 00 00 ff ff 02 00 64 86 63 ae b6 6a 00 00 00 00
      |&mdash;&mdash; Sig1&mdash;&mdash;| |&mdash; Sig2 &mdash;| |&mdash;v2&mdash;| |&mdash;Machine&mdash;| |&mdash;TimeDateStamp&mdash;|
0010: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
0020: 00 00 00 00 00 00 00 00 00 00 00 00 07 00 00 00
      |&mdash;&mdash; 16 bytes of ClassID, all zero&mdash;&mdash;| |&mdash;NumberOfSections&mdash;|
0030: 96 80 46 00 81 11 01 00 2e 74 65 78 74 00 00 00
      |&mdash;PtrToSymTab| |&mdash;NumSyms| |&mdash; ".text" &mdash; the section table</pre>
                </div>
                <p>This is a bigobj header laid out correctly, built from a real 70,017-symbol object by shifting all its data up by 36 bytes and fixing up the symbol table pointer. Handing it to the reference tools produces something more interesting than success or failure:</p>
                <pre><code>$ llvm-readobj --file-headers huge_bigobj.obj
File: huge_bigobj.obj
Format: COFF-import-file-x86-64
Type: code
Name type: ordinal
Symbol: __imp_

$ file huge_bigobj.obj
huge_bigobj.obj: Common Data Format (Version 2.5 or earlier) data</code></pre>
                <p><strong>LLVM recognises the file and misidentifies it as a short-import library.</strong> And the reason is a signature collision:</p>
                <ul>
                    <li>The <strong>short-import</strong> format also begins <code>00 00 FF FF</code>, followed by a version and a machine. Those first four bytes are the whole of its identity as far as LLVM is concerned.</li>
                    <li>A <strong>bigobj</strong> begins <code>00 00 FF FF</code>, followed by <em>its</em> version and machine. The only difference is the version field: 0 for short-import, 2 for bigobj.</li>
                    <li>LLVM dispatches on the signature alone. Set the version to 0 and it is still reported as <code>COFF-import-file-x86-64</code>; set it to 2 and it is reported the same way.</li>
                </ul>
                <p>And the decisive check: the string <code>bigobj</code> does not appear anywhere in the <code>llvm-readobj</code> binary.</p>
                <pre><code>$ strings llvm-readobj | grep -c bigobj
0</code></pre>
                <p>There is no bigobj reader in this LLVM. It cannot be used to confirm a bigobj, and the collision means the file it is instead read as something structurally unrelated.</p>
                <div class="callout callout-warn">
                    <strong>What this means for the course, stated honestly.</strong> The field list above is from the specification, and the layout is confirmed by the fact that a correctly built file parses into a coherent structure by hand. But <strong>no independent reader on this machine accepts a bigobj</strong>, so unlike every other claim in this course it has not been cross-validated against a second implementation. It is taught as a documented layout plus two <em>verified</em> observations &mdash; that clang does not emit one, and that the signature collides with short-import and defeats LLVM &mdash; and not as a decoded example. The <a href="/courses/dwarf/lessons/dwarf-dies">DWARF course</a> handles a comparable situation the same way.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Take the reference object from Module 1 and ask what a classic-layout parser would do with a bigobj. This is the practical content of the concept, and it needs no bigobj to demonstrate.</p>
                <p><code>sample_msvc.obj</code> begins:</p>
                <div class="hex-dump">
                    <pre>0000: 64 86 09 00 2a a5 b6 6a 48 03 00 00 1f 00 00 00
0010: 00 00 00 00 2e 74 65 78 74 00 00 00 00 00 00 00 00
      |&mdash;Machine&mdash;| |&mdash;Secs&mdash;| |&mdash; TimeDateStamp &mdash;| |&mdash;PtrToSymTab&mdash;|
      |&mdash; NumberOfSymbols &mdash;| |opt| |chars|  |&mdash; ".text" &mdash;</pre>
                </div>
                <p>Now feed a bigobj to a parser that does exactly this. It reads:</p>
                <div class="formula">
Machine            = 0x0000        (Sig1)   -&gt; "unknown machine"
NumberOfSections   = 0xFFFF        (Sig2)   -&gt; 65535 sections
TimeDateStamp      = 0x0002        (Version)
PointerToSymbolTable = 0x8664      (Machine)
NumberOfSymbols    = &lt;the real TimeDateStamp&gt;
SizeOfOptionalHeader = &lt;low half of PtrToSymTab&gt;
Characteristics    = &lt;high half of PtrToSymTab&gt;
                    </div>
                <p>Every field is wrong, and the parser has no way to know. A machine value of 0 is at least suspicious; 65,535 sections is entirely plausible-looking; the section table would then be read starting at offset 20, which is 36 bytes before the real one, and would interpret the middle of the <code>ClassID</code> GUID as a section name.</p>
                <p>Compare that with how a malformed <em>classic</em> object fails. Corrupt the <code>Machine</code> field and <code>file</code> reports <code>data</code> and <code>llvm-readobj</code> refuses it. Corrupt <code>NumberOfSections</code> to something absurd and the section table runs off the end of the file. Both produce errors. <strong>The bigobj failure mode is the absence of errors</strong>, which is what makes the format's design worth knowing about even if you never meet one.</p>
                <p>And the defence is cheap: the signature is at offset 0 and costs one comparison.</p>
                <pre><code>w = struct.unpack_from('&lt;I', data, 0)[0]
if w == 0xFFFF:            # Sig1=0, Sig2=0xFFFF -&gt; bigobj
    parse_bigobj(data)
else:
    parse_classic(data)   # check the Machine field for plausibility</code></pre>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ clang --target=x86_64-pc-windows-msvc -c huge.c -o huge.obj
$ llvm-readobj --file-headers huge.obj | grep SymbolCount
$ file huge.obj | grep -o 'COFF object file'</code></pre>
                <p>Then build the variant by hand and watch it fail to be recognised:</p>
                <pre><code>$ python3 -c "
import struct
d = bytearray(open('huge.obj','rb').read())
mach, nsec, ts, symptr, symcnt = struct.unpack_from('&lt;HHIII', d, 0)
hdr  = struct.pack('&lt;HHHH', 0x0000, 0xFFFF, 2, mach)   # Sig1 Sig2 Version Machine
hdr += struct.pack('&lt;I', ts)                            # TimeDateStamp
hdr += bytes(16)                                         # ClassID
hdr += struct.pack('&lt;IIII', 0, 0, 0, 0)                # SizeOfData Flags Meta*
hdr += struct.pack('&lt;III', nsec, 0, symcnt)            # counts + symbol table
out = bytearray(hdr) + d[0x14:]                          # shift everything up
struct.pack_into('&lt;I', out, 48, symptr + len(hdr) - 20) # fix the pointer
open('huge_bigobj.obj','wb').write(out)
"
$ llvm-readobj --file-headers huge_bigobj.obj
$ file huge_bigobj.obj
$ strings $(command -v llvm-readobj) | grep -c bigobj</code></pre>
                <p>Three things to confirm, in order:</p>
                <ul>
                    <li><strong>clang stayed classic</strong> at 70,017 symbols. Raise the count to 200,000 if you like; the header is still 20 bytes. The switch is not automatic in this toolchain.</li>
                    <li><strong>The constructed file is reported as a short-import library</strong>, with <code>Symbol: __imp_</code> &mdash; a symbol that has nothing to do with anything in the file. That is the signature collision, visible.</li>
                    <li><strong>Zero occurrences of <code>bigobj</code></strong> in the reader. This is the honest boundary of the concept: the layout is documented and hand-verified, but not cross-validated, because no tool here implements it.</li>
                </ul>
                <p>And a last check worth doing on a real classic object: verify that the two-word signature does <em>not</em> appear at offset 0 of anything clang emits normally. If it does, you have a short-import file and not an object, and your file-header decoder is about to misparse it exactly as described above.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: a bigobj file is handed to a parser that assumes the classic 20-byte header. It reads <code>Machine</code> as 0 and <code>NumberOfSections</code> as 65535, and no error is raised. Why is that more dangerous than a corrupt classic object, and what single check would have caught it?</p>
                <div class="quiz" id="quiz-coff-bigobj-1">
                    <button class="quiz-option" data-correct="true" data-explain="A corrupt classic object usually produces an implausible value somewhere a reader can check: a machine type that does not exist, a section count that runs off the end of the file, a symbol pointer outside the section. A bigobj produces values that are all individually plausible, because they are real bytes from a real header read at the wrong offsets. The one field that cannot be plausible is the two-word signature at offset 0, and it costs a single comparison." onclick="checkQuiz('quiz-coff-bigobj-1', this)">Because every value it reads is a real byte from a real header at the wrong offset, so they are individually plausible &mdash; and the fix is to test offset 0 for the <code>0x0000FFFF</code> signature before parsing anything else</button>
                    <button class="quiz-option" data-correct="false" data-explain="A classic parser never reaches SizeOfOptionalHeader, because it stops misreading fields long before offset 16. The danger here is specifically that the early fields survive the shift: Sig1 reads as a machine, Sig2 reads as a section count, and both are in range, so the plausibility checks that would catch other corruption do not fire." onclick="checkQuiz('quiz-coff-bigobj-1', this)">Because <code>SizeOfOptionalHeader</code> would be read as a huge value, which no object can have, so the parser would stop immediately</button>
                    <button class="quiz-option" data-correct="false" data-explain="65535 sections is exactly the 16-bit maximum and is entirely representable, so it passes any range check a reader might apply. The format chose that limit precisely so the field's full range is usable, which is also why a bigobj reader has to treat an object claiming the maximum as suspicious for other reasons." onclick="checkQuiz('quiz-coff-bigobj-1', this)">Because 65535 sections is impossible in practice, so any reader that sanity-checks the section count against the file size would reject it</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Your build system starts failing on one machine only. The error is &ldquo;unrecognised object file&rdquo; from a third-party tool, and only for that machine&rsquo;s outputs. Every other machine builds the same source with the same compiler version. What are the plausible causes, and which one does the fact that the failure is <em>machine-specific</em> eliminate?</p>
                <div class="quiz" id="quiz-coff-bigobj-2">
                    <button class="quiz-option" data-correct="true" data-explain="The signature collision is the mechanism that produces exactly this: the file is valid, the machine builds it routinely, and the only difference is which reader sees it. A build that works everywhere except one machine, with an unrecognised-format error from a third-party tool, is the signature of a reader that dispatches on a shared magic number. Checking the Version field immediately after the signature separates the two formats and is a one-line fix." onclick="checkQuiz('quiz-coff-bigobj-2', this)">The failing machine&rsquo;s toolchain emits the <code>00 00 FF FF</code> signature in a form the third-party tool misroutes &mdash; the short-import collision. Machine-specificity eliminates a source or compiler-version problem and points at a <em>reader</em> difference; check the Version field that follows the signature</button>
                    <button class="quiz-option" data-correct="false" data-explain="This would produce a consistent failure everywhere the same source is compiled, not on one machine. A build that is fine on four machines and broken on a fifth is telling you something about the fifth machine, which is exactly what makes the signature collision the useful hypothesis to test first." onclick="checkQuiz('quiz-coff-bigobj-2', this)">The compiler on that machine defaulted to a different target triple, so it emitted COFF for a different architecture and the tool rejected the machine type</button>
                    <button class="quiz-option" data-correct="false" data-explain="An unrecognised-object-format error points at the container, not at a field inside it, and a size that overflowed a 32-bit field would be a very different kind of failure. Worth ruling out, but it does not explain a format-level rejection or why only one machine is affected." onclick="checkQuiz('quiz-coff-bigobj-2', this)">The object exceeded one of the 16-bit limits and a tool silently truncated the count, producing a file that no longer matches its own header</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: when a failure is specific to one machine, suspect a difference in tools rather than in inputs. And when a tool says &ldquo;I do not recognise this format&rdquo;, check the magic number first &mdash; several formats share one, and the version that follows is the only thing that tells them apart.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>The signature collision is the same lesson the <a href="/courses/elf/lessons/elf-identification">ELF identification</a> concept teaches from the other side. ELF opens with four unambiguous magic bytes and then a class byte and a data-encoding byte, so a reader knows the version before it reads anything else. COFF objects have <em>no</em> magic at all, and the one format that does have one shares it. Both are consequences of the same history: COFF grew out of a linker input format and was never given the identification discipline that ELF got deliberately.</p>
                <p>The widened <code>NumberOfSections</code> is the same motivation as the <a href="/courses/dwarf/lessons/dwarf-frames">DWARF 64-bit unit length</a>: a 32-bit field eventually is not enough, and the least disruptive fix is a second format rather than a new version of the first. DWARF signals it with a <code>0xFFFFFFFF</code> escape in the length field; bigobj signals it by taking a signature that means something else entirely.</p>
                <p>Module 3 continues with the container that actually holds these objects &mdash; and which has a magic number that <em>does</em> work.</p>
                <p>Next: <a href="/courses/coff/lessons/coff-archives">The .lib Archive</a>.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/coff/lessons/coff-comdat">Previous: COMDAT and Duplicate Sections</a></span>
                <span><a href="/courses/coff/lessons/coff-archives">Next: The .lib Archive</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
