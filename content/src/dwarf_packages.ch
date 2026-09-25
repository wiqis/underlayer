// DWARF Course — Module 4: Location and Range Lists, Portability, and Packages
// Concept: the .dwp package and .debug_cu_index — how a debugger finds one
// compilation unit inside a file full of them, and why the index exists at all.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_dwarf_packages() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Packages — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson dwarf-lesson">
            <a href="/courses/dwarf" class="back-link">Back to course</a>
            <h1>Packages</h1>
            <div class="lesson-meta">20 min &middot; Module 4: Location Lists, Portability and Packages &middot; Algorithms</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p><a href="/courses/dwarf/lessons/dwarf-split">Split debugging</a> solved a storage problem: the debug information was a large fraction of the binary, and shipping it to every machine was expensive. The fix was to move it out into <code>.dwo</code> files and leave a skeleton behind. But it created a lookup problem, and the problem is worse than it first appears.</p>
                <p>Consider what a debugger actually has when it opens a program. It has one executable, whose skeleton units each name a <code>.dwo</code> file. It has a directory full of <code>.dwo</code> files, possibly hundreds, from possibly dozens of libraries. And the user just pressed a breakpoint in a function whose name they can see in a backtrace.</p>
                <p>To answer "which unit describes this function", the debugger must find <em>the right <code>.dwo</code> file</em> and then <em>the right unit inside it</em>. Scanning every <code>.dwo</code> file, opening each, and walking every unit to compare identifiers works, and it is exactly as slow as it sounds &mdash; on a large C++ program it is seconds of latency before the first breakpoint resolves. The fix is an index, and the index is a file format in its own right.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Two identifiers do the work, and it is worth being precise about each:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Identifier</th><th scope="col">Size</th><th scope="col">What it is</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>The <code>DWO_id</code></td><td>64 bits</td><td>A number in the unit's own header that identifies the unit. Unique per unit, and assigned by the producer</td></tr>
                        <tr><td>The <code>signature</code></td><td>implementation-chosen</td><td>A hash of the <code>.dwo</code> file's contents, so a reader can notice a stale or mismatched file</td></tr>
                    </tbody>
                </table>
                <p>These are different things solving different problems, and conflating them is the usual first mistake. The <code>DWO_id</code> answers <em>which unit is this one</em>. The signature answers <em>is this the file I think it is</em>. A debugger doing a fast lookup needs the first; a build system checking that a <code>.dwo</code> was not rebuilt under it needs the second.</p>
                <p>Now the package. A <code>.dwp</code> file is not a new format &mdash; it is an <em>ordinary ELF object file</em> holding the <code>.dwo</code> sections of many units, concatenated, plus one section that did not exist before:</p>
                <div class="hex-dump">
                    <pre>$ llvm-dwp -e split_exe -o split.dwp
$ readelf -S -W split.dwp | grep -oE '\.debug[a-zA-Z_.0-9]*' | sort -u
.debug_abbrev.dwo
.debug_cu_index
.debug_info.dwo
.debug_line.dwo
.debug_str.dwo
.debug_str_offsets.dwo
</pre>
                </div>
                <p>Every one of those except the last is a section you have already decoded, and the names keep the <code>.dwo</code> <em>contribution suffix</em> &mdash; the marker that tells a linker these are the parts of a split unit, not ordinary debug sections. The content is the same <code>DW_UT_split_compile</code> units that live in the individual <code>.dwo</code> files. <code>readelf</code> and <code>llvm-dwarfdump</code> both open the package and both read its units:</p>
                <pre><code>$ readelf --debug-dump=info split.dwp
Compilation Unit @ offset 0:
   Length:        0xb3 (32-bit)
   Version:       5
   Unit Type:     DW_UT_split_compile (5)</code></pre>
                <p>So a package is a <em>concatenation with an index</em>. The interesting file is the index.</p>
                <div class="callout">
                    <strong>Why not just read the units linearly?</strong> Because the index is not an optimisation, it is a <em>correctness requirement</em> in one specific and common case. A <code>DWO_id</code> is a 64-bit number a producer chose; there is nothing in the format tying it to a unit's position in a file. The same <code>DWO_id</code> could legitimately appear in two different builds with different units in different orders. So "scan until the <code>DWO_id</code> matches" is correct, and it is the slow path the index exists to avoid.
                </div>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>Build a split-DWARF executable, package it, and look at the index:</p>
                <div class="hex-dump">
                    <pre>$ gcc -g -gsplit-dwarf types.c -c -o types.o
$ gcc -g -gsplit-dwarf main.c  -c -o main.o
$ gcc -g types.o main.o -o split_exe
$ ls *.dwo
main.dwo  types.dwo
$ llvm-dwp -e split_exe -o split.dwp
</pre>
                </div>
                <p>The tool is told which file to work from, not which <code>.dwo</code> files to read. It gets the list by walking the skeleton units and reading their <code>DW_AT_dwo_name</code> attributes:</p>
                <pre><code>$ readelf --debug-dump=info split_exe | grep dwo_name
   DW_AT_dwo_name : (indirect string, offset: 0): types.dwo
   DW_AT_dwo_name : (indirect string, offset: 0x1c): main.dwo</code></pre>
                <p>That is the whole discovery mechanism, and it explains why the tool errors out when given the wrong input:</p>
                <pre><code>$ llvm-dwp -e types.o -o x.dwp
warning: executable file does not contain any references to dwo files</code></pre>
                <p>It is not scanning for a file named <code>*.dwo</code> on disk. It reads the executable, follows the references, and packages what it finds. Now the index itself, 144 bytes:</p>
                <div class="hex-dump">
                    <pre>0000: 05 00 00 00 04 00 00 00 02 00 00 00 04 00 00 00
0010: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
0020: 3a c9 20 1a 41 2d e4 5c 0f b3 b9 69 1f 53 96 c2
0030: 00 00 00 00 00 00 00 00 01 00 00 00 02 00 00 00
0040: 01 00 00 00 03 00 00 00 04 00 00 00 06 00 00 00
0050: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
0060: b7 00 00 00 b4 00 00 00 4c 00 00 00 34 00 00 00
0070: b7 00 00 00 b4 00 00 00 4c 00 00 00 34 00 00 00
0080: 95 00 00 00 b3 00 00 00 4a 00 00 00 24 00 00 00
</pre>
                </div>
                <p>All four header fields are four bytes wide, and the values are the useful part:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Bytes</th><th scope="col">Field</th><th scope="col">Value</th><th scope="col">Means</th></tr>
                    </thead>
                    <tbody>
                        <tr><td><code>05 00 00 00</code></td><td><code>version</code></td><td>5</td><td>The index has its own version field, independent of the units it indexes</td></tr>
                        <tr><td><code>04 00 00 00</code></td><td><code>section_count</code></td><td>4</td><td>How many sections are indexed &mdash; the five unit sections minus <code>.debug_cu_index</code> itself</td></tr>
                        <tr><td><code>02 00 00 00</code></td><td><code>unit_count</code></td><td>2</td><td>Two units packaged: <code>types.dwo</code> and <code>main.dwo</code></td></tr>
                        <tr><td><code>04 00 00 00</code></td><td><code>slot_count</code></td><td>4</td><td>The size of a hash table that would let a lookup find a unit by hashing a signature</td></tr>
                    </tbody>
                </table>
                <p>Two of those deserve a moment. <code>section_count</code> is 4 and the package has 5 unit-bearing sections, because the index does not index itself. And <code>slot_count</code> is 4 while <code>unit_count</code> is 2: the hash table is a fixed-size structure chosen at package time, independent of how many units went in, and it is a trade of table size for lookup speed. Four slots for two units is nearly half empty. The producer could have made a hundred-unit package with the same four slots, and then most lookups would fail and fall back to a scan.</p>
                <h3>The <code>DWO_id</code> values are in the index, in full</h3>
                <p>Bytes <code>0x20</code> to <code>0x2f</code> hold two 8-byte little-endian numbers. Compare them with what the units themselves declare:</p>
                <div class="hex-dump">
                    <pre>index  0020: 3a c9 20 1a 41 2d e4 5c   = 0x5ce42d411a20c93a
index  0028: 0f b3 b9 69 1f 53 96 c2   = 0xc296531f69b9b30f

$ llvm-dwarfdump --debug-info split.dwp | grep DWO_id
  unit 0: DWO_id = 0x5ce42d411a20c93a
  unit 1: DWO_id = 0xc296531f69b9b30f
</pre>
                </div>
                <p>They are the same numbers, byte for byte. That is the index doing its one job, and it is the fact worth remembering: <strong>a debugger holding a <code>DWO_id</code> &mdash; obtained from the skeleton unit in the executable &mdash; can look it up in the index and jump straight to the right unit, without opening any other <code>.dwo</code> file and without walking a single unit header.</strong></p>
                <p>Contrast that with the naive path. To find the same unit, a reader would have to read both <code>.dwo</code> files from disk, read each unit's header far enough to find its <code>DWO_id</code> field, and compare. The index reduces that to arithmetic on a table that is already in memory. On a large program with hundreds of units, the difference between a scan and a lookup is the difference between a debugger that feels instant and one that does not.</p>
                <div class="callout callout-warn">
                    <strong>Where this walk stops, and why that is the honest place to stop.</strong> The four header fields, the two <code>DWO_id</code> values, the section list and the fact that both reference readers open the package are all established above. The <em>trailing offset table</em> is not. The header plus the hash table plus the signatures plus four sections of two offsets accounts for 80 of the 144 bytes, and the remaining 64 could not be attributed to a single reading of the layout &mdash; a sixteen-byte block is visibly duplicated at offsets <code>0x60</code> and <code>0x70</code>, which is not a shape any single-table reading explains. <code>0xb7</code> does appear in that region and does match the offset of the second unit, which is suggestive, but suggestive is not the same as accounted for.
                    <br /><br />
                    So the exact geometry of the tail is not taught here, and the number 144 is not offered as a derivation. What is taught is the header, which is fully decoded and which is the part a reader must get right first: the version, the section count, the unit count, and the slot count. A reader that has those four right and then guesses the tail will produce a table of wrong offsets; a reader that rejects the file because the tail did not decode is behaving correctly. If you work out the tail, that is a real finding and it belongs in a reader, not in a guess.
                </div>
                <h3>What the index does not do</h3>
                <p>Three things it is easy to assume and worth ruling out explicitly, because the file gives no hint either way:</p>
                <ul>
                    <li><strong>It does not contain debug information.</strong> No DIE, no line number, no type. Every one of the 144 bytes is about <em>where the debug information is</em>. That is the difference between an index and a cache, and it is why the index is 144 bytes for 2 units while the units themselves are kilobytes each.</li>
                    <li><strong>It does not reference files.</strong> There is no path in it. A package is self-contained, which is the point &mdash; the alternative, indexing by filename, would go stale the moment a file moved, and the whole failure mode of split debugging is files moving independently of executables.</li>
                    <li><strong>It is not verified.</strong> Nothing checks that the unit at the indexed offset is the unit the <code>DWO_id</code> claims. A <code>DWO_id</code> collision, or a package built from a different set of files than the executable names, produces a lookup that succeeds and returns the wrong unit. This is a real hazard and it is why the separate <code>signature</code> mechanism exists.</li>
                </ul>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Answering "give me the <code>DW_TAG_subprogram</code> named <code>total</code>" against a split, packaged build. Every step is one of the joins from the concepts before it:</p>
                <div class="formula">
step 1   the executable's skeleton unit names types.dwo
         and carries that unit's DWO_id
         -> from .debug_info, DW_AT_dwo_name and the unit header

step 2   is there a package? if so, open it once and read
         the .debug_cu_index header
         -> version, section_count, unit_count, slot_count

step 3   take the DWO_id from step 1, look it up in the
         index -> an offset into the packaged .debug_info
         no package, or not found?
         -> open the .dwo by name and scan its unit headers
            for a matching DWO_id. slower, and correct.

step 4   at that offset is a DW_UT_split_compile unit
         -> the same header as always, so the normal DIE
            walk applies unchanged

step 5   the unit is a skeleton in the executable and a
         split unit in the package; read the attributes
         from the package, because that is where the
         children are
</div>
                <p>Step 5 is the one that produces the most confusing bugs, so it is worth being explicit about the division of labour. In a split build, <strong>the skeleton unit and the split unit are not the same unit.</strong> They are two units that share a <code>DWO_id</code>, and they carry different attributes. The skeleton in the executable holds the attributes a linker needs: <code>DW_AT_low_pc</code>, <code>DW_AT_ranges</code>, <code>DW_AT_stmt_list</code> &mdash; the ones that say <em>where</em>. The split unit in the <code>.dwo</code> or the <code>.dwp</code> holds the ones a type system needs: <code>DW_AT_name</code>, <code>DW_AT_type</code>, <code>DW_AT_byte_size</code> &mdash; the ones that say <em>what</em>.</p>
                <p>So the lookup you sketched in step 4 is not a simplification. A debugger genuinely does read <em>two different units</em> and join them on the <code>DWO_id</code>, and the join is the reason the identifier exists. A reader that reads the whole unit out of the package and the whole unit out of the executable and concatenates them gets duplicates; a reader that reads only the package has no addresses; a reader that reads only the executable has no types. Each of those three mistakes produces a debugger that works until the moment it needs the half it is missing.</p>
                <p>And the cost of not packaging at all is worth stating as a number rather than an adjective. Without a <code>.dwp</code>, step 3 is a scan: open every <code>.dwo</code>, read every unit header, compare <code>DWO_id</code>. With one, step 3 is a table lookup. The number of files read goes from <em>all of them</em> to <em>one</em>, and the amount of unit data parsed goes from <em>all of it</em> to <em>one header</em>. Everything after step 3 is identical work either way, which is why packaging is worth a file format.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ llvm-dwp -e split_exe -o split.dwp
$ readelf -S -W split.dwp
$ llvm-dwarfdump --debug-info split.dwp | head -8
$ readelf --debug-dump=info split.dwp | head -8</code></pre>
                <ul>
                    <li><strong>Package something big and feel the difference.</strong> Split a real project, package it, and time the two paths in step 3 with the package present and removed. The gap is the argument for the whole feature, and it is much larger than expected once the project has a few hundred units.</li>
                    <li><strong>Verify the <code>DWO_id</code> match from both ends.</strong> Read the <code>DWO_id</code> out of the packaged unit with <code>llvm-dwarfdump</code>, read the same field out of the skeleton in the executable, and read the bytes at <code>0x20</code> in the index by hand. Three sources, one value. If any of them disagree, stop and find out why before trusting a lookup.</li>
                    <li><strong>Watch the <code>slot_count</code> trade.</strong> Package the same project with a larger index unit size and compare the resulting <code>slot_count</code> and section size. Then reason about what happens to lookups that miss &mdash; and about which is better for a debugger holding one unit in memory.</li>
                    <li><strong>Try to break the join.</strong> Package the executable, then rebuild <em>only</em> the object that produced one of the <code>.dwo</code> files so that it gets a new <code>DWO_id</code>, and rebuild the executable too but leave the package stale. Now ask what a debugger does. This is the failure mode the <code>signature</code> mechanism exists to catch, and seeing the gap is more instructive than reading about it.</li>
                    <li><strong>Finish the offset table yourself.</strong> The tail of <code>.debug_cu_index</code> is the one thing in this concept that is not accounted for. You have the section, the header, and two known-good offsets from the tool. Work out the geometry, and if you cannot, notice what evidence would settle it &mdash; that is the same discipline that produced the loclists adjudication two concepts ago, applied to your own file.</li>
                </ul>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: a debugger has a skeleton unit from the executable. That unit carries a <code>DW_AT_dwo_name</code> and a <code>DWO_id</code>. A <code>.dwp</code> package exists and is loaded. What does the debugger do with the <code>DWO_id</code>, and what would it have to do differently if the package did not exist?</p>
                <div class="quiz" id="quiz-dwarf-packages-1">
                    <button class="quiz-option" data-correct="true" data-explain="That is the entire purpose of the index. The DWO_id is the join key between the skeleton in the executable and the split unit in the package, and the index maps it to an offset, so the debugger reads one unit header instead of every unit in every file. The cost structure is what makes it worth a format: files read drops from all of them to one, and unit data parsed drops from all of it to a single header. The scan without a package is not incorrect, which is the subtle part: it is the same answer, arrived at by reading everything." onclick="checkQuiz('quiz-dwarf-packages-1', this)">It looks the <code>DWO_id</code> up in the package's <code>.debug_cu_index</code> and jumps to the offset it names, opening one unit instead of scanning every <code>.dwo</code> file. Without a package it must open each <code>.dwo</code> and read every unit header until one matches &mdash; the same answer, found by brute force</button>
                    <button class="quiz-option" data-correct="false" data-explain="The index contains 144 bytes of offsets for two units and none of the DWO_ids in the compiled sources, so it cannot be searched for a name. The name lives in the split unit's DW_AT_name, which is exactly the data the package is indexing the location of rather than duplicating. Searching an index by symbol name would require the index to contain the debug information, which is the opposite of the design." onclick="checkQuiz('quiz-dwarf-packages-1', this)">It searches the index for the <code>DWO_id</code> of every unit, finds the one whose indexed name matches the symbol, and reads the function from that unit</button>
                    <button class="quiz-option" data-correct="false" data-explain="This confuses the identifier's job. The DWO_id identifies a compilation unit so a reader can find it, not so it can validate a file. Nothing in the DWO_id can detect a file that was replaced, because the replacement is free to reuse the same id. Checking that a file matches its name is the signature's job, and it is a separate mechanism with a separate purpose." onclick="checkQuiz('quiz-dwarf-packages-1', this)">It uses the <code>DWO_id</code> to verify that the <code>.dwo</code> file named by <code>DW_AT_dwo_name</code> is the right one, and skips the package unless the signature matches</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>A debugger on a large C++ project shows correct types, correct line numbers, and correct variable values. Symbol lookup, however, takes eight to ten seconds after a restart, and only on a cold cache &mdash; the second time it runs it is instant. The project is built with <code>-gsplit-dwarf</code> and the <code>.dwp</code> is present. Given what you have just decoded, what is the most likely explanation, and what is the cheapest experiment that would confirm it without changing the build?</p>
                <div class="quiz" id="quiz-dwarf-packages-2">
                    <button class="quiz-option" data-correct="true" data-explain="The pattern is diagnostic. Correct values rule out every content bug: the debugger is reading real types, real line numbers and real locations, so the whole DWARF pipeline works. The cost is on lookup specifically, which points at how it finds units rather than how it reads them. The cold/warm asymmetry narrows it further: something is being read from disk on the first lookup and cached afterwards, which is exactly what a scan of .dwo files looks like and exactly what an index lookup does not. A scan that is correct, complete, and O(all units) explains all three observations at once. The reason the package is not being used is a separate question from the symptom, and the file layout is the way to answer it, since the index is the only mechanism that turns scanning into a lookup." onclick="checkQuiz('quiz-dwarf-packages-2', this)">The debugger is not using the index, so it falls back to scanning every <code>.dwo</code> file's unit headers for a matching <code>DWO_id</code>. That is correct, which is why the values are right, but it is proportional to the number of units &mdash; and the cold/warm asymmetry is the giveaway, because the scan result is what gets cached. The cheapest check is to look for <code>.debug_cu_index</code> in the <code>.dwp</code> and confirm the debugger reads it</button>
                    <button class="quiz-option" data-correct="false" data-explain="Correct line numbers rule out a .debug_line problem directly: the line program is being read and applied successfully, and it is the same kind of data in the same section group. A failure to find or parse the line program would produce no line numbers at all, not correct ones that are slow to arrive at." onclick="checkQuiz('quiz-dwarf-packages-2', this)">The line number program is being decoded very slowly, because <code>.debug_line</code> is large and the debugger parses the whole of it before answering the first query</button>
                    <button class="quiz-option" data-correct="false" data-explain="The scan reads unit headers, not unit contents, so it would be proportional to the number of units rather than their size. A program large enough to be a problem for header scanning would be a program with hundreds of translation units, and for those the total .dwo data is still small. The scan cost is about the count of units, not the volume of debug data, which is why the size argument points the wrong way." onclick="checkQuiz('quiz-dwarf-packages-2', this)">The <code>.dwo</code> files are too large to read over the network filesystem, and the delay is I/O time rather than lookup logic</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: separate "the answer is wrong" from "the answer takes too long". Correctness bugs live in the decode path and performance bugs live in the search path, and they rarely share a cause. When values are right and latency is wrong, stop reading the data and go look at how it is being found.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>This concept is the payoff for <a href="/courses/dwarf/lessons/dwarf-split">split debugging</a>, which introduced the <code>DWO_id</code> and the skeleton idea without being able to explain what the identifier was <em>for</em>. It is also the payoff for <a href="/courses/dwarf/lessons/dwarf-lookup">putting a lookup together</a>: that walk assumed one unit in one file, and this is the case where the unit and the file are separate and the identifier is the join.</p>
                <p>The shape of the solution is one this course has now seen three times, and recognising it is the transferable part. A table of identifiers mapping to positions in a file, so a reader can go straight to what it needs: the <code>.debug_pubnames</code> and <code>.debug_gnu_pubnames</code> sections you used in Module 3 map a name to a DIE; <code>.debug_aranges</code> maps an address range to a unit; <code>.debug_cu_index</code> maps a <code>DWO_id</code> to a unit in a package. Each replaces a scan of everything with a lookup in a small table, and each is optional in the sense that a debugger works without it &mdash; just more slowly.</p>
                <p>That closes Module 4, and with it the parts of DWARF that can be checked against files on this machine. The next module goes after the thing DWARF is read alongside but is a different format entirely: the unwind information, read straight from the binary, and what a debugger does when there is no debug info at all.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/dwarf/lessons/dwarf-portability">Previous: Same Source, Different Target</a></span>
                <span><a href="/courses/dwarf">Back to course</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
