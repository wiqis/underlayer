// JVM Course — Module 1: The Container
// Concept: modified UTF-8 — the encoding CONSTANT_Utf8 actually uses, which is
// not the one it is named after.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_jvm_strings() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Modified UTF-8 — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson jvm-lesson">
            <a href="/courses/jvm" class="back-link">Back to course</a>
            <h1>Modified UTF-8</h1>
            <div class="lesson-meta">21 min &middot; Module 1: The Container &middot; Algorithms</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Every name in a class file is a <code>CONSTANT_Utf8</code> entry: every class name, every method name, every descriptor, every string literal, every generic signature. <strong>It is the only tag in the pool that carries text rather than a number or a reference</strong>, and it is the one every other tag eventually points at.</p>
                <p>Which makes its encoding the single most consequential non-numeric decision in the format. And the encoding is called UTF-8 and is not UTF-8.</p>
                <p>That is not a rhetorical flourish. <strong>A standard UTF-8 decoder, handed the bytes of a valid Java class file, fails on it.</strong> Not on a rare string &mdash; on any class file containing a supplementary character, which is any class file containing an emoji, and on any class file containing a NUL, which is rarer but entirely legal. This course's own decoder did exactly that while it was being written, and the failure is the best available demonstration that the deviation is real rather than a detail in a specification nobody reads.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>What the pool entry looks like, and then what is actually inside it:</p>
                <div class="formula">
CONSTANT_Utf8:
    tag          0x01
    length       u2, the number of BYTES that follow
    bytes        that many bytes, in "modified UTF-8"
</div>
                <p>The length is in bytes, not characters, and not UTF-16 code units. <strong>Those three are different numbers for the same string</strong> and the format only ever stores the first, which means a reader that wants a character count has to count after decoding. Worth holding on to, because it is the reason the surrogate case below exists at all.</p>
                <p>Standard UTF-8 encodes a character in one to four bytes depending on its code point: one for ASCII, two for the rest of Latin-1, three for the rest of the Basic Multilingual Plane, four for anything above U+FFFF. Modified UTF-8 changes exactly two of those cases, and the changes are both in service of Java's type system rather than of text.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <h3>Deviation one: NUL is two bytes</h3>
                <p>Java source containing a string with an embedded NUL, compiled and read back:</p>
                <div class="hex-dump">
                    <pre>  Java source:      "a\0b"
  pool entry:      61 c0 80 62          length = 4
                  |  |  |
                  |  |  +-- 0x62 = 'b'
                  |  +----- 0x80: continuation of a 2-byte sequence
                  +-------- 0xc0: a 2-byte lead that is OVERLONG

  standard UTF-8 would be:   61 00 62        length = 3
</pre>
                </div>
                <p><strong>A NUL costs two bytes in a class file, and one of them is <code>0xC0</code> &mdash; a lead byte that is deliberately overlong.</strong> The reasoning is about tools rather than languages: NUL is the traditional terminator for a C string, and a class file's strings are read by C and C++ tools constantly &mdash; linkers, debuggers, <code>strings</code>, hex dumpers. If a <code>CONSTANT_Utf8</code> could contain a real zero byte, every one of those tools would silently truncate the string at that point and read a shorter name than the file intended.</p>
                <p>So the format makes a NUL <em>unrepresentable as a single byte</em>. The byte pair <code>0xC0 0x80</code> decodes to U+0000, and no standard UTF-8 sequence is a NUL at all, because a well-formed UTF-8 encoder never emits an overlong sequence. <strong>That is the design in one sentence: the deviation exists so that the one byte value every string tool treats as "the end" can never appear inside the data.</strong></p>
                <p>And it has a consequence in the <em>language</em> too, which is a nice illustration of a file format leaking back into source. In Java you cannot write the NUL as <code>"\u0000"</code>, because the unicode pre-processor runs over the source <em>before</em> parsing and would inject a raw zero byte into the token stream, breaking the lexer. The only way is the octal escape <code>"\0"</code>. That asymmetry &mdash; <code>\u0000</code> illegal, <code>\0</code> required &mdash; is a direct consequence of the on-disk encoding, three layers away from the string it affects.</p>
                <h3>Deviation two: a supplementary character costs six bytes</h3>
                <p>This one is the more surprising, and it has a clean explanation that makes it feel less like a mistake once you know it. Take an emoji, U+1F389:</p>
                <div class="hex-dump">
                    <pre>  Java source:      "hi \uD83C\uDF89"
  pool entry:      68 69 20 ed a0 bc ed be 89       length = 9
                                    |  |     |  |  |
                                    |  |     |  +----- 0x89: the low surrogate
                                    |  |     +-------- 0xbe: third byte of it
                                    |  +-------------- 0xed: a 3-byte lead
                                    +----------------- 0xa0-bc: 0xDF89 encoded
                                                      as its own 3-byte sequence

  standard UTF-8 would be:   68 69 20 f0 9f 8e 89       length = 7
                            (one 4-byte sequence, the character itself)
</pre>
                </div>
                <p><strong>Six bytes where real UTF-8 uses four, and the reason is that the format stores the UTF-16 surrogate pair, not the character.</strong> The emoji is outside the Basic Multilingual Plane, so Java represents it as two <code>char</code> values &mdash; <code>U+D83C</code> and <code>U+DF89</code> &mdash; because a <code>char</code> is sixteen bits by definition. Modified UTF-8 encodes each of those two halves as its own three-byte sequence. The encoding is called CESU-8 and it is a real thing with real uses, but it is not UTF-8, and the two disagree on exactly one class of character: those above U+FFFF.</p>
                <p>You can see the rule in the lead bytes. <code>0xED</code> is the standard three-byte lead for code points <code>U+D000</code> to <code>U+D7FF</code> in real UTF-8 &mdash; which is precisely the <strong>high surrogate range</strong>. So real UTF-8 can already encode a high surrogate; it just never encodes a <em>pair</em>. Modified UTF-8 takes that existing ability and uses it for the second half of the pair. <strong>Nothing new was added to the encoding; the format simply uses a part of the existing space that UTF-8 had reserved and left empty.</strong> That is why the deviation is only six bytes and not something more elaborate.</p>
                <div class="callout callout-warn">
                    <strong>And here is the demonstration, because it happened in this course's own tooling.</strong> The decoder shipped with this course was written to read <code>CONSTANT_Utf8</code> as ordinary UTF-8, with one adjustment for the <code>0xC0 0x80</code> NUL. Run against <code>Str.class</code>, it <strong>threw</strong>: <code>'utf-8' codec can't decode byte 0xed in position 3: invalid continuation byte</code>. That is not a subtle wrong answer &mdash; a conforming UTF-8 decoder rejecting a valid class file is exactly the symptom, and it is how a careful reader would discover this. <strong>The fix has an order to it that is easy to get wrong:</strong> recombine the surrogate pairs <em>first</em>, and only then collapse the <code>0xC0 0x80</code> pairs. Do it the other way round and you decode to a string containing two lone surrogate characters, which cannot be re-encoded to UTF-8 at all &mdash; so a decoder that decodes correctly and then cannot round-trip is worse than one that throws, because it fails silently at the point where the data is written back out.
                </div>
                <h3>What the two deviations have in common</h3>
                <p>Neither one is about representing text better. <strong>Both are about keeping the encoding compatible with something else.</strong> The NUL is two bytes so that C string tools cannot truncate a name. The supplementary character is six bytes so that the encoding matches the <code>char</code>-based string model the language already had, rather than introducing a fourth width that the runtime's own primitives do not have.</p>
                <p>And that is a pattern worth naming, because it recurs across this collection. <a href="/courses/wasm/lessons/wasm-header">The class file's big-endian ordering</a> exists so a file is unmistakably a class file. <a href="/courses/wasm/lessons/wasm-leb128">A WebAssembly <code>i32</code></a> has no unsigned variant because the language had no unsigned integers. Here a text encoding is bent away from the standard so that a family of existing tools keeps working. <strong>In each case the format is choosing to be slightly wrong in a direction that keeps some other thing intact</strong>, and in each case the cost lands on whoever writes a decoder rather than on whoever reads the text.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Decoding a <code>CONSTANT_Utf8</code> correctly, which is a two-pass operation and the order is the whole trick:</p>
                <div class="formula">
decode_modified_utf8(bytes) -> str:

    # PASS 1: recombine surrogate pairs into real characters.
    #         Must happen first. A decoded lone surrogate cannot be
    #         re-encoded as UTF-8, so deferring this produces a string
    #         that decodes fine and then fails to serialise.
    out = []
    i = 0
    while i &lt; len(bytes):
        if bytes[i] == 0xED and is_surrogate_tail(bytes[i+1..i+2]):
            hi = 0xD000 | ((bytes[i+1] & 0x3F)  &lt;&lt; 6) | (bytes[i+2] & 0x3F)
            if next three bytes are also an encoded low surrogate:
                lo = 0xD000 | (...)
                out.append(chr(0x10000 + ((hi - 0xD800)  &lt;&lt; 10) + (lo - 0xDC00)))
                i += 6
            else:
                out.append(REPLACEMENT)     # unpaired: do NOT drop it silently
                i += 3
        else:
            out.append(bytes[i]);  i += 1

    # PASS 2: collapse the two-byte NUL.
    return utf8_decode(out).replace("\xC0\x80", "\x00")
</div>
                <p>Three things in that are decisions rather than mechanics.</p>
                <p><strong>Pass 1 before pass 2, and the reason is round-tripping.</strong> If you collapse the NUL pairs first you get a byte string containing a real <code>0xC0 0x80</code> sequence, which UTF-8-decodes to U+0000, and then pass 1 has to recognise a zero byte as a surrogate lead &mdash; which it never will, because <code>0x00</code> is not <code>0xED</code>. So the two passes do not commute, and the order is forced by the data rather than by taste. <strong>Getting it wrong does not crash; it produces a string that cannot be written back out</strong>, which is the worse failure because it surfaces much later and somewhere else entirely.</p>
                <p><strong>An unpaired surrogate is preserved, not dropped.</strong> A malformed or hand-built class file can contain an encoded high surrogate with no low surrogate after it. A decoder that skips it produces a shorter string, and a shorter class name is a different class &mdash; so the decoder's job is to report the problem, not to tidy it away. The shipped decoder emits U+FFFD, which is the conventional choice and is at least visible: a reader that sees replacement characters knows something was wrong, where a silently dropped surrogate leaves a name that looks fine and resolves to nothing.</p>
                <p>And <strong>the length is in bytes, so the decoder cannot trust it as a character count</strong> &mdash; but it can and must trust it as a byte count, because it is what says where the entry ends. A <code>CONSTANT_Utf8</code> is the <em>only</em> variable-length entry in the pool, so this length is the single field the whole pool walk depends on. <strong>If it is wrong, every subsequent entry is misread</strong>, which is why the payload sizes in the <a href="/courses/jvm/lessons/jvm-constant-pool">pool walk</a> are stated as <code>2 + n</code> rather than as a fixed size, and why a decoder that assumes fixed-size entries cannot read this format at all.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ javap -v -p out/Str.class
$ python3 courses/jvm/assets/samples/class_decode.py out/Str.class --cp-only
$ python3 courses/jvm/assets/samples/crosscheck.py classes/Str.class</code></pre>
                <ul>
                    <li><strong>Find the NUL and count its bytes.</strong> Compile <code>"a\0b"</code>, find the entry, and count. Then try <code>"\0"</code> and <code>"\u0000"</code> and see which one the compiler accepts. <strong>One of them is a compile error and the reason is a file format three layers down</strong> &mdash; that is the finding, and finding it yourself is worth more than being told.</li>
                    <li><strong>Find the six-byte emoji and decode it by hand.</strong> Locate the entry, confirm the two three-byte sequences, and combine the surrogate pair yourself. <strong>Then check that the byte count and the character count differ</strong> &mdash; a string with one NUL and one emoji has a length field that is not the number of characters and not the number of <code>char</code> values either.</li>
                    <li><strong>Write a strict UTF-8 decoder and watch it fail.</strong> Feed it the pool entry bytes directly. Then add the NUL fix and watch it still fail on the emoji. <strong>Two separate fixes, discovered in two separate failures</strong>, which is exactly how the real deviation presents itself.</li>
                    <li><strong>Break the pass order deliberately.</strong> Swap the two passes in the shipped decoder and find a string that decodes to the right characters but cannot be re-encoded. <strong>A decoder that reads correctly and cannot write back is a worse bug than one that throws</strong>, and this is the cheapest way to feel the difference.</li>
                    <li><strong>Find the boundary of the deviation.</strong> Compile <code>"\u00FF"</code> (two bytes, standard), <code>"\uFFFF"</code> (three, standard) and <code>"\uD83C\uDF89"</code> (six, modified). <strong>U+FFFF is the last code point that is still ordinary UTF-8, and the deviation starts exactly one code point later</strong> &mdash; locating that boundary is the whole concept in one experiment.</li>
                    <li><strong>Check whether a supplementary character fits in a <code>char</code>.</strong> It does not: <code>char c = '\uD83C\uDF89';</code> is a compile error, and the message says the literal contains more than one UTF-16 code unit. <strong>The error is the format's data model leaking into the language's type system</strong>, and it is the reason the six-byte encoding exists.</li>
                </ul>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: a <code>CONSTANT_Utf8</code> entry in <code>Str.class</code> is nine bytes long and decodes to the four characters <code>h</code>, <code>i</code>, space, and U+1F389. Why is the length nine and not four, and what would a standard UTF-8 decoder do with those nine bytes?</p>
                <div class="quiz" id="quiz-jvm-strings-1">
                    <button class="quiz-option" data-correct="true" data-explain="Three byte counts are in play and only one of them is stored. The string has four characters, so four is the character count. It needs two UTF-16 code units, because a character above the Basic Multilingual Plane occupies a surrogate pair in Java's model, so two is the char count. And it needs six bytes on disk, because modified UTF-8 encodes each surrogate separately as a three-byte sequence rather than encoding the character as one four-byte sequence the way real UTF-8 would. That makes the total 3 plus 6, which is 9, and it is the byte count the length field stores. A standard UTF-8 decoder fails on those nine bytes, and it is worth being precise about why: the sequence ed a0 bc is a three-byte lead in the range that real UTF-8 reserves for high surrogates, and a strict decoder correctly identifies that the code point it decodes is a surrogate, which real UTF-8 forbids outside paired use. So the decoder's objection is not that the bytes are malformed but that they are well-formed UTF-8 encoding something the standard says should not appear alone. That distinction is what makes the failure confusing in practice: a tool reports a decoding error about a file that is entirely valid." onclick="checkQuiz('quiz-jvm-strings-1', this)">The length is a byte count and modified UTF-8 spends six bytes on the emoji because it encodes the UTF-16 surrogate pair as two three-byte sequences rather than the character as one four-byte sequence. A standard UTF-8 decoder rejects the bytes, because <code>ed a0 bc</code> is a well-formed lead that decodes to a lone surrogate &mdash; which the standard forbids</button>
                    <button class="quiz-option" data-correct="false" data-explain="The nine bytes are the correct answer, and the reason is the interesting part, so getting the count right while getting the reason wrong still misses the finding. The emoji is not four bytes here, and it is not four because the format does not store characters at all: it stores UTF-16 code units, and a character outside the Basic Multilingual Plane is two of them. Each is encoded separately in three bytes, giving six. A four-byte encoding would be the real UTF-8 representation of the code point, and using it would have meant the on-disk form no longer matched the runtime's own string representation. As for the standard decoder, it does reject the bytes, so that half is right, but the reason matters: the bytes are not malformed, they are well-formed UTF-8 that encodes a lone surrogate, which the standard disallows." onclick="checkQuiz('quiz-jvm-strings-1', this)">The length is nine because the format stores a byte count and the emoji is six bytes in real UTF-8 while the three ASCII characters are three, so 3 plus 6 equals 9. A standard UTF-8 decoder handles these bytes correctly and produces the right four characters</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>You are writing a tool that reads class files and re-emits them, for example to rename a class. It works on every class in your build. On a dependency compiled from source that happens to contain one non-ASCII string, it produces an output file the JVM will not load, with no error from your tool &mdash; the write succeeded. Decoding the string back gives you the correct characters. What is the defect, why did nothing complain, and what is the check that would have caught it before the file was written?</p>
                <div class="quiz" id="quiz-jvm-strings-2">
                    <button class="quiz-option" data-correct="true" data-explain="The symptoms narrow this to one specific mistake with very little room left. Decoding produces the correct characters, so the read side is right. The write produces a file the JVM rejects, so the encode side is wrong. And the only encoding the read side can produce that is correct-but-unencodable is a string containing lone surrogates, which is exactly what you get if pass 1 of the decoder runs after pass 2 &mdash; or, equivalently, if the decoder collapses the C0 80 NUL pairs before recombining surrogate pairs, leaving a byte stream in which the surrogate leads are no longer recognisable. The reason nothing complained is the important half of the question and it is structural rather than accidental: the format has no round-trip check. A class file stores strings, and nothing in the file records what those strings should encode back to, so there is no way for a writer to notice that its own output is not reproducible. That is why the check has to be one you impose: decode the pool, re-encode every string, decode again, and compare. That is cheap, it needs no specification, and it catches every bug in this family including the ones you have not thought of. The general habit is that whenever a format gives you a decode, ask immediately what the matching encode is and whether the two are inverse &mdash; because a format that stores only one direction never tells you the round trip is lossy until something downstream rejects the file." onclick="checkQuiz('quiz-jvm-strings-2', this)">The decoder recombines surrogates in the wrong order relative to collapsing the NUL pairs, so it yields correct characters that contain lone surrogates and cannot be re-encoded as UTF-8. Add a round-trip check: decode every pool string, re-encode it, decode again, and compare &mdash; the format has no such check of its own</button>
                    <button class="quiz-option" data-correct="false" data-explain="This is worth ruling out and the evidence rules it out cleanly. If the NUL handling were wrong you would see the wrong characters, because a C0 80 pair left in place would decode to a replacement or a visible artefact rather than a NUL, and the report says decoding gives the correct characters. There is also nothing in the scenario suggesting the class contains a NUL at all, so the NUL branch is not exercised. The failure is specific to characters above the Basic Multilingual Plane, and the only way to decode those correctly and then be unable to write them back is a surrogate-pair handling order error." onclick="checkQuiz('quiz-jvm-strings-2', this)">The NUL handling is wrong, so the string decodes to the right visible characters but the length field is computed from a character count rather than a byte count, and the output's lengths are all off by a few bytes</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: whenever a format hands you a decoder, work out the matching encoder and test that the two are inverse. A format that stores only one direction will not tell you the round trip is lossy &mdash; something downstream will, and it will be a file that will not load.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>CESU-8 is not an invention of the class file format, and the course is more useful for saying so. It is a real, standardised encoding designed for exactly the constraint Java has: <strong>a runtime whose fundamental character type is sixteen bits, on a platform where the encoding has to interoperate with tools that assume standard UTF-8.</strong> The same problem, and the same answer, appear in <a href="/courses/elf/lessons/elf-identification">ELF's <code>ELFCLASS</code> and <code>ELFDATA</code></a> bytes, which encode the same kind of decision in two bytes instead of in a string encoding. The pattern is the one this course keeps meeting: <strong>the format's encoding is a consequence of the runtime it has to fit inside</strong>, and understanding the runtime explains the encoding without needing the specification.</p>
                <p>The NUL decision has a direct parallel in the other formats, and it is a decision about <em>tools</em> rather than about the language. <a href="/courses/coff/lessons/coff-string-table">A COFF string table</a> prefixes each string with a four-byte length instead of terminating it with a zero, for the same reason: a length prefix permits embedded NULs where a terminator cannot, and a format read by C tools should not depend on C's conventions. <a href="/courses/wasm/lessons/wasm-data">A WebAssembly data segment</a> makes the same choice for the same reason, and so does <a href="/courses/pe/lessons/pe-imports">a PE import name</a> only <em>not</em> &mdash; which is a genuine inconsistency in that format and a useful contrast. <strong>Length-prefix versus NUL-terminated is one of the most consequential small decisions in any binary format, and this course now has four examples of it, three of them length-prefixed.</strong></p>
                <p>Both deviations are instances of a broader idea that runs through this whole course, and it is worth naming before the course moves on to the code inside a method. <strong>Every encoding decision in a binary format is a decision about which mistake is easier to make.</strong> The magic catches a non-class-file in four bytes. The big-endian order catches a byte-swapped reader immediately. The two-slot rule makes a mis-sized index fetch produce an invalid tag rather than a wrong value. The NUL encoding makes a truncating tool produce a visibly wrong name. And modified UTF-8's second deviation makes a standard decoder <em>fail loudly</em> rather than silently return the wrong character &mdash; which is why this concept could be written at all: the deviation announces itself to anyone using a conforming tool.</p>
                <p>A format designed to be wrong quietly is much harder to teach and much harder to debug, and it is the more common choice in practice. The class file is unusually well made in this respect. <a href="/courses/jvm/lessons/jvm-intro">Back to the start of the course</a> for the four readers, or forward to Module 2 for what happens after the pool: the fields, the methods, and the <code>Code</code> attribute where the actual instructions live.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/jvm/lessons/jvm-constant-pool">Previous: The Constant Pool</a></span>
                <span><a href="/courses/jvm/lessons/jvm-intro">Back to the start of the course</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
