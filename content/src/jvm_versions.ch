// JVM Course — Module 5: Linking and Versioning
// Concept: version history — what each major version added, and the pattern
// behind thirty years of additions.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_jvm_versions() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Version History — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson jvm-lesson">
            <a href="/courses/jvm" class="back-link">Back to course</a>
            <h1>Version History</h1>
            <div class="lesson-meta">20 min &middot; Module 5: Linking and Versioning &middot; Foundations</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Everything in this course was added to a format that shipped in 1995 and has not changed shape since. Records, lambdas, sealed types, modules, nest access, generic signatures, annotations, string concatenation via <code>invokedynamic</code> &mdash; <strong>not one of them required a new file layout, a new section, or a new index.</strong></p>
                <p>That is a genuinely unusual outcome. Most binary formats that survive thirty years do so by adding structures, and the structures accumulate until the format is a sequence of version-gated branches. The class file avoided that, and the <a href="/courses/jvm/lessons/jvm-header">header concept</a> already showed how: <code>major_version</code> is the Java release number, and a class compiled for an older release is exactly as readable as it was the day it shipped.</p>
                <p>So the interesting question is not "what changed" but <strong>"how did it change thirty times without the format changing?"</strong> There are exactly two answers in the whole design, and this course has spent five modules on them: the <a href="/courses/jvm/lessons/jvm-attributes">attribute mechanism</a> for things that <em>describe</em>, and the <code>invokedynamic</code> bootstrap for things that <em>execute</em>. Everything else follows from those two.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>The version is two numbers at a fixed offset, and the <a href="/courses/jvm/lessons/jvm-header">first module's finding</a> about the minor version bears repeating because this concept depends on it:</p>
                <div class="formula">
  offset 4:  u2 minor_version   0, or 65535 (0xFFFF) for "preview"
  offset 6:  u2 major_version   52 = Java 8, 55 = Java 11, 61 = Java 17,
                                65 = Java 21, 70 = Java 26

  major = 45 + the Java feature release number
</div>
                <p><strong><code>minor_version = 65535</code> means a preview build, and it is the only non-zero value a shipped class ever has.</strong> That is a feature flag occupying a field that could have held a sub-version, and it is the first of two decisions that explain the whole history: the version numbers things that would break existing readers, and nothing else.</p>
                <p>Because that is the actual rule. <strong>A new major version is issued when a class file with the new features would be rejected by an old JVM</strong> &mdash; and with the attribute mechanism and <code>invokedynamic</code> in place, that is almost never. A class using records, sealed types, or nest attributes is rejected by a Java 8 JVM only because the version says 61, not because the structure is incomprehensible. <strong>Every feature in this module set the version number and nothing else.</strong></p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>One source file, compiled at four release levels, and the measurements. This is the whole argument in a table, and every number came from <code>javac --release</code> followed by <code>javap</code>:</p>
                <div class="hex-dump">
                    <pre>  ONE source file: a lambda, a method reference, a
  functional interface, and a string concatenation.

  release  major  bytes  indy  boots  StringBuilder  NestMembers
  -------  -----  -----  ---  -----  -------------  -----------
      8      52    1608    2      2            10        no
     11      55    1806    4      4             0       yes
     17      61    1806    4      4             0       yes
     21      65    1806    4      4             0       yes
</pre>
                </div>
                <p>Two findings in that table, and the first is the sharp one.</p>
                <p><strong>Java 11 made the file 198 bytes <em>larger</em>.</strong> That is counter-intuitive enough to be worth explaining rather than stating. The increase is not the nest attributes &mdash; a six-entry <code>NestMembers</code> is 14 bytes. It is the string concatenation. At release 8 the concatenation was a <code>StringBuilder</code> chain in the bytecode; at release 11 it is two extra <code>invokedynamic</code> instructions, two extra bootstrap entries, and the associated pool entries, and the <code>StringBuilder</code> chain is gone entirely. <strong>The <code>StringBuilder</code> pattern was never cheaper at run time &mdash; the JIT had eliminated it for years &mdash; so moving it into the constant pool cost bytes and saved nothing, and bought uniformity.</strong></p>
                <p>And here is the <code>StringBuilder</code> chain that disappeared, which is worth reading because it is a whole algorithm written out in bytecode by a compiler rather than by a programmer:</p>
                <div class="hex-dump">
                    <pre>  release 8, ten instructions for "n=" + n:

    15: new           #28    // class java/lang/StringBuilder
    18: dup
    19: invokespecial #30    // StringBuilder."&lt;init&gt;":()V
    22: ldc           #31    // String n=
    24: invokevirtual #33    // StringBuilder.append(Ljava/lang/String;)...
    27: iload_2
    28: invokevirtual #37    // StringBuilder.append(I)...
    31: invokevirtual #40    // StringBuilder.toString:()Ljava/lang/String;
    34: astore_3

  release 11, five bytes:

    ??: invokedynamic #?, 0  // makeConcatWithConstants:(
                            //   Ljava/lang/String;I)Ljava/lang/String;
</pre>
                </div>
                <p><strong>Ten instructions, seven pool entries, and a <code>StringBuilder</code> that never needed to exist</strong> &mdash; replaced by five bytes and one <code>Utf8</code> recipe. The interesting part is that the old form was <em>also</em> wasteful in a way that was visible in the file: <code>new StringBuilder</code> allocates on every concatenation, and a JIT had to recognise and remove it. The <code>invokedynamic</code> form removes the need for that optimisation, not by being faster but by never expressing the problem.</p>
                <h3>The synthetic lambda methods, unchanged across all four</h3>
                <p>One detail that cuts against a tidy narrative. The synthetic methods are <code>lambda$main$0</code> and <code>lambda$main$1</code> in <em>all four</em> releases &mdash; identical, byte for byte:</p>
                <div class="hex-dump">
                    <pre>  private static java.lang.String lambda$main$0();
  private static int lambda$main$1(java.lang.String);

  the naming scheme:  lambda$enclosingMethod$counter
  (and lambda$new$N for a lambda in a constructor)
</pre>
                </div>
                <p><strong>So the two lambdas cost the same generated code in 2008's compiler and in 2020's.</strong> The <code>invokedynamic</code> mechanism did not remove the synthetic method &mdash; it made it a <em>parameter</em> to a bootstrap rather than the target of a call, and the method is still there with the same name and the same body. <strong>What changed was who decides what to do with it.</strong> That is a good corrective to the usual framing: the lambda's implementation was never the expensive part, and it never was.</p>
                <h3>What each version actually added</h3>
                <p>The list, restricted to things this course has verified in files rather than things it has not:</p>
                <div class="hex-dump">
                    <pre>  45  Java 1.1     invokedynamic and BootstrapMethods existed
                            in the format from the start and were UNUSED for
                            five years. The instruction was there waiting.
  49  Java 5       ACC_SYNTHETIC, ACC_BRIDGE, generic Signature attribute
  50  Java 6       StackMapTable
  51  Java 7       invokedynamic put to work for string concatenation
  52  Java 8       lambdas via LambdaMetafactory
  55  Java 11     NestHost, NestMembers; string concat moves off
                            StringBuilder; varargs-style stack map changes
  60  Java 16     records (Record attribute), ACC_RECORD on components
  61  Java 17     sealed types (PermittedSubclasses)
  65  Java 21     record patterns, pattern-matching switch
  66  Java 22     the classfile API (java.lang.classfile)
  70  Java 26     -- this course's own samples, compiled here
</pre>
                </div>
                <p><strong>Every row after 45 is an attribute, a flag, or a use of an existing instruction.</strong> Not a single structural change. Compare the same thirty years in <a href="/courses/pe/lessons/pe-optional-header">a PE</a>, where the optional header grew by dozens of fields, or <a href="/courses/elf/lessons/elf-identification">ELF</a>, where three <code>e_type</code> values and two <code>EI_OSABI</code> values were added &mdash; <strong>all additive, and all in the version field, which is what a version field is for.</strong> The difference is that the PE and ELF additions are new fields in an existing structure, so an old reader walking the old structure is fine but an old reader walking the <em>new</em> structure is not, and the version is the only defence. The class file's additions are new attributes, and a skipped attribute is not merely tolerated but <em>defined</em> to be harmless.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>The two mechanisms, and why the format needed only two. This is the synthesis of the whole course, and it is worth stating as a classification because it applies to any format that has to survive being extended:</p>
                <div class="formula">
  the ONLY two ways this format has ever grown:

  1. AN ATTRIBUTE -- for anything that DESCRIBES
       a name, a length, and contents the old reader skips.
       Used for: SourceFile, LineNumberTable, Signature,
       RuntimeVisibleAnnotations, Record, PermittedSubclasses,
       InnerClasses, NestHost, NestMembers, Module, BootstrapMethods

  2. A BOOTSTRAP -- for anything that EXECUTES
       a bootstrap method, run once, computing a target
       the instruction then calls directly.
       Used for: lambdas, method references, string concatenation

  everything else is a FLAG or a POOL TAG:
     ACC_ENUM, ACC_SYNTHETIC, ACC_RECORD, ACC_MODULE, ACC_TRANSITIVE
     CONSTANT_InvokeDynamic, CONSTANT_MethodHandle, CONSTANT_MethodType
     CONSTANT_Module, CONSTANT_Package, CONSTANT_Dynamic
</div>
                <p><strong>And the division of labour is not arbitrary &mdash; it is exactly the split the <a href="/courses/jvm/lessons/jvm-attributes">escape hatch concept</a> drew between the closed instruction stream and the open attribute list.</strong> A format that executes code from a data file must be able to extend what it executes, and the only way to do that without a new opcode is to make the existing opcode's target a computed thing. That is what <code>invokedynamic</code> is, and it is why it was in the specification in 1995 and unused until 2006: <strong>the mechanism was designed in from the start, and the language had nothing to use it for yet.</strong></p>
                <p>Compare that with a format that had to add features and could not use either mechanism. <a href="/courses/dwarf/lessons/dwarf-versions">DWARF</a> is versioned by tag ranges, so a new tag cannot collide with an old one and an old reader skips a whole version &mdash; <strong>which works, but it means the producer and consumer must agree on a version, and a producer that emits DWARF 5 for a consumer that knows DWARF 4 gets nothing rather than most of the data.</strong> The class file's reader gets everything except the attributes it does not know, which is a strictly better degradation, and it is available because the extension point is a name and a length rather than a version boundary.</p>
                <p>The honest cost, and there is one. <strong>Because every addition is invisible to old readers, there is no upper bound on how much a class file can accumulate</strong> &mdash; twenty-four distinct attribute names across this course's twenty-four samples, with <code>SourceFile</code> and <code>InnerClasses</code> repeated because the pool shares them. A large project accumulates a stack of attributes most tools ignore, and the file grows without any version negotiation. <strong>That is a real cost and it is the mirror of the benefit:</strong> a format where an old reader degrades gracefully also has no mechanism forcing a new reader to be written, and the "just update your JDK" answer is a real maintenance burden that the format's design does not solve for you.</p>
                <p>And one structural gap worth naming, since this concept is the natural place for it. <strong>The <a href="/courses/jvm/lessons/jvm-modules"><code>Module</code> attribute</a> is the one major feature that used neither mechanism</strong> &mdash; it is positional, with no name and no length delimiting its sections, and a sixth kind of directive would need a new major version. So the answer "the format never needed a new layout" is true for every feature in this course except one, and that one is instructive precisely because it is a departure. <strong>Nearly everything grew additively; the one feature big enough to need its own structure was the one that could not, and it is the only part of the format a new reader must be taught structurally rather than by name.</strong></p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ javac --release 8 -d out8 V.java
$ javac --release 11 -d out11 V.java
$ javap -v -p out8/V.class | head -5</code></pre>
                <ul>
                    <li><strong>Reproduce the size inversion.</strong> The table above is the experiment. <strong>Compile one file at <code>--release 8</code> and <code>--release 11</code> and compare sizes</strong> &mdash; the newer one is larger, and the reason is string concatenation, not the nest attributes. Working out the 198 bytes is the exercise.</li>
                    <li><strong>Diff the attribute lists across four releases.</strong> <code>--release 8 / 11 / 17 / 21</code> and list the class-level attributes at each. <strong>One name is added at 11 and nothing at all after</strong> &mdash; which is the additive mechanism in a single observation, and the fact that 17 and 21 add nothing is the surprising part.</li>
                    <li><strong>Count the pool entries that exist only for the nest.</strong> <code>NestHost</code> and <code>NestMembers</code> plus the <code>Utf8</code> names. <strong>Compare that to the <code>StringBuilder</code> entries they replaced</strong>, and check which direction the balance moved.</li>
                    <li><strong>Confirm the synthetic methods are identical across versions.</strong> Dump the method list at <code>--release 8</code> and at <code>--release 21</code>. <strong>Byte-identical names and bodies</strong> &mdash; so the lambda's implementation cost never changed, and what <code>invokedynamic</code> changed was who calls it.</li>
                    <li><strong>Load a record with a Java 8 JVM.</strong> Not a hypothetical: run an old JVM against a class with major 61 and read the error. <strong>It is rejected purely on the version number</strong> &mdash; the structure is comprehensible and it is refused anyway, which is the clearest demonstration that the version gates features rather than syntax.</li>
                    <li><strong>Read a preview class file.</strong> <code>javac --enable-preview --release 26</code> and check <code>minor_version</code>. <strong>65535, and the only non-zero minor version a class ever has</strong> &mdash; a field that looks like a sub-version and is a feature flag.</li>
                    <li><strong>Invent a sixth <code>Module</code> section and see what the spec requires.</strong> <strong>Not an attribute, not additive &mdash; a new major version</strong>, because the five sections are positional and there is nowhere to put a sixth count. Then put the same feature in an attribute and watch the format accept it. That contrast is the concept's conclusion as a single experiment.</li>
                </ul>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: the same source compiled at <code>--release 8</code> and <code>--release 11</code> produces files of 1608 and 1806 bytes. The release 8 file has 10 <code>StringBuilder</code> references and 2 <code>invokedynamic</code> instructions; the release 11 file has 0 and 4. The release 11 file is 198 bytes larger. Where did the extra bytes go, and why is the answer not "the nest attributes"?</p>
                <div class="quiz" id="quiz-jvm-versions-1">
                    <button class="quiz-option" data-correct="true" data-explain="The extra bytes are the string concatenation, and the mechanism is worth being precise about because the intuition runs the other way. At release 8 the concatenation is a StringBuilder chain: new, dup, invokespecial on the constructor, an ldc of the literal, two append calls, a toString, and a store. That is ten instructions and roughly seven pool entries -- a Class for StringBuilder, a Methodref for its constructor, two Methodrefs for the appends, a Methodref for toString, and the literal itself. At release 11 those are replaced by five bytes of invokedynamic plus its InvokeDynamic entry, its NameAndType, the descriptor strings, and a BootstrapMethods entry carrying the recipe. The point is that the old form was not a run-time cost either -- the JIT had recognised and eliminated the StringBuilder for years -- so this was a change with no performance motivation at all. It bought uniformity: the concatenation became a constant the bootstrap interprets once, instead of a pattern every JIT has to know how to remove. The nest attributes are the smaller contribution and the obvious red herring, since a six-entry NestMembers is 14 bytes and this file has only one nest member. A file growing across a version boundary is genuinely counter-intuitive, and this is the reason." onclick="checkQuiz('quiz-jvm-versions-1', this)">String concatenation. The <code>StringBuilder</code> chain's ten instructions and seven pool entries were replaced by two extra <code>invokedynamic</code> instructions, their bootstrap entries and pool entries &mdash; a change that bought uniformity and cost bytes, because the <code>StringBuilder</code> form was never a run-time cost either. The nest attributes are 14 bytes, and they are the obvious red herring</button>
                    <button class="quiz-option" data-correct="false" data-explain="The attribution is wrong and the mechanism is the interesting part, because the StringBuilder chain was never a run-time cost in the first place -- the JIT had been eliminating it for years, which is why removing it from the bytecode changed nothing measurable. So there is no performance argument for the file growing, and if the nest attributes were the cause the story would be coherent: a new feature adding a new attribute should make a file larger. What actually happened is the opposite of a feature being added, since the StringBuilder chain was removed and a different encoding took its place. The nest attributes are a genuine addition and a small one, which is exactly what makes them a tempting answer for a size difference -- a 14-byte attribute is a real 14 bytes. But the 198-byte difference is a net effect of removing one mechanism and adding another, and a tool that attributed it to the attribute would be right by coincidence and wrong by reasoning." onclick="checkQuiz('quiz-jvm-versions-1', this)">The nest attributes, since <code>--release 11</code> is the first version that emits <code>NestHost</code> and <code>NestMembers</code> and they are additive content the older compiler had no room for, so the file necessarily grew to hold them</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>You are writing a class file reader for a long-lived tool that has to analyse build output from projects using any JDK from 6 to 26. It parses the header, reads the pool, and walks members. It handles attributes by name and skips what it does not recognise. On a Java 8 project's output it works. On a Java 21 project's output it fails immediately with <code>major version 65 not supported</code>, having read nothing else. The file is structurally no different. What is the defect, and what is the strongest evidence in the situation that the version number is a gate rather than a description of the file's structure?</p>
                <div class="quiz" id="quiz-jvm-versions-2">
                    <button class="quiz-option" data-correct="true" data-explain="The defect is that the tool is closed where the format is open, and it is the same mistake as the attribute-skipping exercise in Module 3 applied one level up. The version number is a promise about which features may appear, not a description of what does appear, and a reader that treats it as a version gate for its own capability is applying a rule the format never imposed. The evidence is decisive and there is a lot of it. The tool already skips unknown attributes by name, so its own architecture is open where the format is open -- the version check is inconsistent with the tool's own design. The structure of the file is unchanged, so nothing about parsing it requires the new knowledge. The header concept established the rule: a new major version is issued when an old JVM would reject the class, and a reader is not an old JVM -- it has no such obligation. And the version numbers in this format are tied to the language release rather than to format structure, so a project on a newer JDK running older language features emits a higher major version with no new structure whatsoever, which means the gate is close to random with respect to what a reader actually needs to know. The general habit is to distinguish a field that constrains a consumer from a field that describes a producer, and to notice that the same mechanism can enforce the first only when the consumer chooses to." onclick="checkQuiz('quiz-jvm-versions-2', this)">The tool is treating a feature-gate number as a capability test. It should not gate on <code>major_version</code> at all &mdash; the version says which features <em>may</em> appear, not what the file requires a reader to know. The tool already skips unknown attributes, so its own design is open; the failure is on a file that is structurally no different, and the format places no obligation on a reader to reject a newer version</button>
                    <button class="quiz-option" data-correct="false" data-explain="The recommendation is reasonable and the diagnosis is wrong, and the difference is a real one rather than a matter of phrasing. A class file with a major version higher than a JVM supports is genuinely unrunnable on that JVM -- the loader refuses it, which is a real constraint and a real reason a tool might reasonably be conservative. But this is not a JVM, and a reader has no such obligation: it can skip an unknown attribute and stay correct, so the gate the format imposes on a runtime does not transfer to an analyser. The evidence is in the tool's own behaviour. It already skips attributes it does not recognise, so it is open where the format is open, and the version check contradicts that policy rather than expressing it. The strongest point is the last one: because major version tracks the Java language release rather than the format's structure, a project on a newer JDK emitting only long-established features still gets a higher number -- so gating on it rejects files that need nothing new, which is the definition of a gate that is not describing the file." onclick="checkQuiz('quiz-jvm-versions-2', this)">The tool should widen its version range to the versions it has been tested against and report anything outside as a warning rather than a failure, since a higher major version only means the file may use features the tool has not seen</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: distinguish a field that constrains a consumer from a field that describes a producer. A runtime is obliged to refuse a version it cannot run; a reader is not, and a version number is a ceiling, not a description.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Thirty years of the same problem, and this course has the whole range. <a href="/courses/elf/lessons/elf-identification">ELF's <code>EI_VERSION</code></a> is 1 and always has been. <a href="/courses/pe/lessons/pe-optional-header">A PE's <code>MajorOperatingSystemVersion</code></a> is a minimum-kernel requirement and the loader honours it. <a href="/courses/coff/lessons/coff-symbol-table">A COFF object's characteristics</a> say what the linker may assume. <a href="/courses/dwarf/lessons/dwarf-versions">DWARF versions</a> partition the tag space. <strong>Every format answers the same question &mdash; how does a reader handle a file from a producer it does not know &mdash; and every one picks a different level of strictness</strong>, from ELF's permanent version 1 to DWARF's version-partitioned tag ranges to the class file's skip-the-attribute rule.</p>
                <p>The class file's answer is the most permissive, and it is worth being honest about why that is not free. <strong>Because skipping is always safe, a reader that skips everything it does not know is correct on every file ever produced</strong> &mdash; which is a guarantee no other format in this collection makes. The price is that nothing forces anyone to adopt a new feature's semantics. An old reader will not reject a class using records; it will simply not know it is a record, and will report it as a class. <strong>Silent, correct, partial degradation is a better failure mode than a loud rejection, and it is also a harder one to notice.</strong> Compare DWARF, where a consumer that cannot read version 5 knows immediately that it has less than it needs, because the version told it so.</p>
                <p>The two mechanisms are the format's whole story, and each is a general technique rather than a Java solution. <strong>Attribute-as-escape-hatch is <a href="/courses/wasm/lessons/wasm-objects">a WebAssembly custom section</a></strong> with a different payload, and it is how <a href="/courses/dwarf/lessons/dwarf-versions">DWARF</a> and <a href="/courses/pe/lessons/pe-data-directories">a PE's data directory</a> both work. <strong>Bootstrap-as-deferred-linking is <a href="/courses/elf/lessons/relocation-entries">an ELF relocation</a></strong> generalised from writing an address to running a program, and it is why <code>invokedynamic</code> could carry lambdas and string concatenation without either asking the format to change. If you take one architectural idea from this course, it is that <strong>a format survives by keeping its <em>executed</em> vocabulary small and fixed while pushing everything new into a deferred layer</strong> &mdash; and the class file has been doing exactly that, deliberately or not, since 1995.</p>
                <p>Which leaves the honest questions, and a course that skipped them would be worse for it. <strong>Is the attribute mechanism past its limit?</strong> There are now over a hundred defined attribute names, several of them nearly identical, and the naming has grown inconsistent &mdash; <code>RuntimeVisibleAnnotations</code> against <code>Signature</code> against <code>Record</code>, three conventions in one list. A consolidated attribute with a sub-kind field would be cleaner, and cannot be introduced without breaking every existing reader, which is the escape hatch working exactly as designed. <strong>And can a <code>javap</code> that prints <code>Unknown</code> for two pool tags be trusted on the ones it does know?</strong> Yes &mdash; this course's cross-check had all three readers agree on 25 files including the module one &mdash; but it is a reminder that a tool's <em>labels</em> lag its <em>parsing</em>, and that verifying a reader means comparing structure against something independent rather than against its own output.</p>
                <p>That is the end of the course. <a href="/courses/jvm/lessons/jvm-intro">From a magic number</a> to a format that computes its own instructions, through a constant pool that is 69% of a hello-world, a string encoding that is not the one it is named after, two offset conventions in one attribute, a verifier's conclusions written into the file, and two extension mechanisms that let a thirty-year-old format absorb every language feature since. <strong>The version number never moved because the format never had to. The lesson is not about Java.</strong></p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/jvm/lessons/jvm-modules">Previous: Modules</a></span>
                <span><a href="/courses/jvm">Back to course</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
