// JVM Course — landing page
public namespace underlayer_content {

using std::string

using std::string_view

public func render_jvm_landing() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("JVM Class File Format — Underlayer")
    page.appendTitle(&title)

    #css {
        .course-landing { max-width: 900px; margin: 0 auto; padding: 2rem 1.5rem 4rem; }
        .course-header { margin-bottom: 2rem; }
        .course-header h1 { font-size: 2.2rem; margin: 0 0 0.5rem; letter-spacing: -0.02em; }
        .course-description { color: #4b5563; line-height: 1.65; margin: 0 0 1.25rem; }
        .course-meta { display: flex; flex-wrap: wrap; gap: 0.5rem; }
        .meta-item { background: #f3f4f6; border: 1px solid #e5e7eb; border-radius: 999px;
                     padding: 0.25rem 0.75rem; font-size: 0.85rem; color: #374151; }
        .module { margin: 2.5rem 0; }
        .module h2 { font-size: 1.35rem; margin: 0 0 0.5rem; }
        .module > p { color: #4b5563; line-height: 1.65; margin: 0 0 0.9rem; }
        .concept-list { list-style: none; padding: 0; margin: 0; }
        .concept-list li { border: 1px solid #e5e7eb; border-radius: 8px; padding: 0.7rem 0.9rem;
                           margin-bottom: 0.5rem; display: flex; justify-content: space-between;
                           align-items: baseline; gap: 1rem; background: #fff; }
        .concept-list a { color: #1d4ed8; text-decoration: none; font-weight: 500; }
        .concept-list a:hover { text-decoration: underline; }
        .concept-time { color: #6b7280; font-size: 0.85rem; white-space: nowrap; }
        .module-note { font-size: 0.9rem; color: #6b7280; margin-top: 0.75rem; line-height: 1.6; }
        .callout { border-left: 4px solid #3b82f6; background: #eff6ff; padding: 1rem 1.1rem;
                   border-radius: 0 8px 8px 0; margin: 1.5rem 0; line-height: 1.65; }
        .callout-warn { border-left-color: #f59e0b; background: #fffbeb; }
        .callout strong { display: block; margin-bottom: 0.35rem; }
        .course-footer-note { margin-top: 3rem; padding-top: 1.5rem; border-top: 1px solid #e5e7eb;
                              color: #6b7280; line-height: 1.65; font-size: 0.95rem; }
        code { background: #f3f4f6; padding: 0.1rem 0.3rem; border-radius: 4px; font-size: 0.9em; }
    }

    #html {
        <div class="course-landing" id="main-content">
            <div class="course-header">
                <h1>JVM Class File Format</h1>
                <p class="course-description">A Java compiler does not produce a program. It produces a
                file &mdash; one self-contained artifact that a virtual machine can load, check, and
                refuse. This course takes that file apart, one field at a time, with three
                independent implementations agreeing on every byte.</p>
                <div class="course-meta">
                    <span class="meta-item">2 modules</span>
                    <span class="meta-item">8 concepts</span>
                    <span class="meta-item">Intermediate</span>
                    <span class="meta-item">~168 min</span>
                </div>
            </div>

            <div class="callout callout-warn">
                <strong>What you need first.</strong> You should be comfortable reading a binary header
                and following offsets by hand, so <a href="/courses/elf/lessons/elf-header-fields">ELF</a>
                or <a href="/courses/coff/lessons/coff-file-header">COFF</a> would be useful preparation.
                You do not need to know Java, and you do not need to have written a class file by
                hand &mdash; every sample here was produced by <code>javac</code> on this machine.
            </div>

            <div class="callout">
                <strong>How this course was verified.</strong> Four independent implementations read
                every sample. <code>javap -v</code>, the JDK's own disassembler. A decoder written
                from the specification and shipped with this course, which is deliberately
                <em>not</em> a validator. <code>java.lang.classfile</code>, the JDK's own standard
                parsing API, which reaches the parser through a supported interface rather than
                through a disassembler. And the JVM verifier itself, which accepts or refuses and
                shares no code with the other three. The comparison harness is shipped too, and it
                was itself tested by injecting faults &mdash; including one it initially failed to
                catch, for a reason that is written up in the research record.
            </div>

            <div class="module-list" id="module-list">
                <div class="module">
                    <h2>Module 1: The Container</h2>
                    <p>Everything before the code. The header, the fixed order that follows it, the
                    table the whole file is made of, and the text encoding that table uses. This
                    module is the foundation: once the constant pool is right, everything after it
                    is mechanical.</p>
                    <ul class="concept-list">
                        <li><a href="/courses/jvm/lessons/jvm-intro">Why a Class File</a> <span class="concept-time">15 min</span></li>
                        <li><a href="/courses/jvm/lessons/jvm-header">The Header and the Fixed Order</a> <span class="concept-time">18 min</span></li>
                        <li><a href="/courses/jvm/lessons/jvm-constant-pool">The Constant Pool</a> <span class="concept-time">24 min</span></li>
                        <li><a href="/courses/jvm/lessons/jvm-strings">Modified UTF-8</a> <span class="concept-time">21 min</span></li>
                    </ul>
                    <p class="module-note">Four findings in this module are worth reading for even if
                    you skip the rest. The format is big-endian throughout, which is the opposite
                    of every other format in this collection and is stated in the first four bytes.
                    <code>CONSTANT_Long</code> and <code>CONSTANT_Double</code> consume two pool
                    indices, so some indices are permanently unusable &mdash; and the JDK's own API
                    throws when you ask for one. <code>CONSTANT_Utf8</code> is not UTF-8: a NUL
                    costs two bytes and an emoji costs six, and a conforming UTF-8 decoder rejects
                    the file. And the pool is 69% of a hello-world, which is the argument for the
                    format's central design decision in one number.</p>
                </div>

                <div class="module">
                    <h2>Module 2: Members and Code</h2>
                    <p>Everything after the constant pool: what a class has, what it can do, and
                    the code that runs. This is where the format stops being a name table and
                    starts describing behaviour &mdash; and where two of the sharpest traps in
                    the whole format live.</p>
                    <ul class="concept-list">
                        <li><a href="/courses/jvm/lessons/jvm-members">Fields, Methods and Descriptors</a> <span class="concept-time">22 min</span></li>
                        <li><a href="/courses/jvm/lessons/jvm-code">The Code Attribute</a> <span class="concept-time">21 min</span></li>
                        <li><a href="/courses/jvm/lessons/jvm-branches">Two Offset Conventions</a> <span class="concept-time">24 min</span></li>
                        <li><a href="/courses/jvm/lessons/jvm-stackmaps">The Verifier's Data</a> <span class="concept-time">23 min</span></li>
                    </ul>
                    <p class="module-note">Three findings here are worth the module on their own.
                    Instruction branch offsets are <strong>relative to the branch's own opcode
                    address</strong> while exception table offsets in the same attribute are
                    <strong>absolute</strong>, so the error from getting it wrong is a different
                    amount at every branch. A <code>long</code> or <code>double</code> takes
                    <strong>two local slots</strong> &mdash; the third appearance of the same 64-bit
                    rule that gives a <code>Long</code> two pool indices. And the
                    <code>StackMapTable</code> exists because a compiler writes down the result
                    of a type analysis so the verifier can check it instead of redoing it.</p>
                </div>
            </div>

            <div class="course-footer-note">
                <p>Modules 3 onward &mdash; the long tail of attributes that has no section table to
                live in: <code>InnerClasses</code> and the <code>$1</code> numbering,
                <code>Signature</code> for generics, annotations, records, sealed classes, and
                modules &mdash; are specified in <code>courses/jvm/research.md</code> and not yet
                written. The question they raise is how a format with no extensibility
                mechanism at the top level accommodated twenty years of new features, and the
                attribute is the answer.</p>
                <p>The section-framing idea this format shares with the others is covered from the
                other side in the <a href="/courses/elf">ELF</a> and
                <a href="/courses/coff">COFF</a> courses. And the format that has the most in common
                with this one &mdash; a big-endian, index-everything, length-prefixed container with
                a no-partial-compatibility rule &mdash; is
                <a href="/courses/wasm">WebAssembly</a>.</p>
            </div>
        </div>
    }

    return page.toString()
}
}
