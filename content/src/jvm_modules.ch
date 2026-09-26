// JVM Course — Module 5: Linking and Versioning
// Concept: modules — the Module attribute, CONSTANT_Module, and the two pool
// tags javap still labels Unknown.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_jvm_modules() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Modules — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson jvm-lesson">
            <a href="/courses/jvm" class="back-link">Back to course</a>
            <h1>Modules</h1>
            <div class="lesson-meta">20 min &middot; Module 5: Linking and Versioning &middot; Algorithms</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Java spent fifteen years without any way to say "this class belongs to that library and must not see anything else". The class path was one flat namespace, every class was public or private, and encapsulation stopped at the package boundary whether or not the package was meant to be an API. Then Java 9 added modules, and the mechanism they use is <strong>the strangest in this course: two constant pool tags that the JDK's own disassembler does not recognise.</strong></p>
                <p>Here is the finding that makes this concept worth its own lesson. <code>javap</code> &mdash; the reference disassembler, shipped with the JDK, used in the <a href="/courses/jvm/lessons/jvm-intro">first concept</a> as one of three independent readers &mdash; prints <code>CONSTANT_Module</code> and <code>CONSTANT_Package</code> as <code>Unknown</code>:</p>
                <div class="hex-dump">
                    <pre>  $ javap -v -p module-info.class

     #6 = Unknown            #7             // "com.example.demo"
     #8 = Unknown            #9             // "java.base"
    #13 = Unknown            #14            // com/example/api
    #15 = Unknown            #16            // com/example/internal
    #17 = Unknown            #12            // "com.example.friend"
    #19 = Unknown            #20            // com/example/model
</pre>
                </div>
                <p><strong>It reads them correctly and names them "Unknown".</strong> The Utf8 it resolves is right, so the tool understands the structure; it just has no name for the tag. And that is a genuinely useful thing to know about a thirty-year-old disassembler: <strong>tags 19 and 20 are so rarely used that the tool that has shipped with every JDK for three decades still has no label for them.</strong> It is a direct measurement of how unusual a feature is.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Two new pool tags, and they are the simplest in the format &mdash; one name index each:</p>
                <div class="formula">
CONSTANT_Module:
    u1 tag = 19
    u2 name_index      a Utf8: a module name, dots not slashes
                       "com.example.demo"

CONSTANT_Package:
    u1 tag = 20
    u2 name_index      a Utf8: a package name, SLASHES
                       "com/example/api"
</div>
                <p>Three bytes each, and that is the whole thing. <strong>Neither is a <code>CONSTANT_Class</code></strong>, which is the design point worth noticing: a class entry's <code>name_index</code> points at an <em>internal</em> name (<code>com/example/api/Service</code>) because that is what the JVM needs to resolve, whereas a module's or a package's name is a human-facing dotted or slashed identifier that the resolution logic never uses. <strong>So the two new tags are names for the benefit of readers, and the format gave them their own tags rather than overloading <code>Class</code> to mean three things.</strong></p>
                <p>That is the opposite choice from <a href="/courses/jvm/lessons/jvm-annotations">the annotation's enum and class values</a>, which were flattened into <code>CONSTANT_Utf8</code> strings because they needed no identity. Modules and packages <em>do</em> need identity &mdash; the same module name appears in many files and a reader compares them &mdash; so each got a pool tag that can be shared. <strong>One of those decisions is right and the other is right for a different reason, and the difference is whether the name has to be found by reference or only read.</strong></p>
                <h3>The Module attribute, which is five sections</h3>
                <p>The attribute is the one place the module's whole declaration lives, and it is five variable-length sections with no overall count:</p>
                <div class="formula">
Module:
    u2 module_name_index          a CONSTANT_Module
    u2 module_flags               usually 0
    u2 module_version_index       a CONSTANT_Utf8, or 0

    u2 requires_count            then that many requires entries
    u2 exports_count             then that many exports entries
    u2 opens_count               then that many opens entries
    u2 uses_count                then that many class indices
    u2 provides_count            then that many provides entries
</div>
                <p><strong>No section ids, no tags, no end markers</strong> &mdash; the five sections follow each other in a fixed order and the counts tell you where each ends. That is the opposite design from the <a href="/courses/jvm/lessons/jvm-attributes">escape hatch</a>, where each thing carries its own name and length. Here everything is positional, which means <strong>a reader must know the order to read it at all</strong>, and adding a sixth kind of directive would require a new major version rather than an attribute.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>A real <code>module-info.class</code>, compiled from a nine-line source, 370 bytes, 24 constant pool entries and one 56-byte attribute:</p>
                <div class="hex-dump">
                    <pre>  flags: (0x8000) ACC_MODULE

  Module:
    #6,0                                  // "com.example.demo"
    #0
    2                                     // requires
      #8,0                                // "java.base"
      #10                                 // 26.0.1
      #11,20                              // "java.logging" ACC_TRANSITIVE
      #10                                 // 26.0.1
    2                                     // exports
      #13,0                               // com/example/api
      #15,0                               // com/example/internal to ... 1
        #17                               // ... to "com.example.friend"
    1                                     // opens
      #19,0                               // com/example/model
    1                                     // uses
      #21                                 // com/example/api/Service
    1                                     // provides
      #21                                 // com/example/api/Service with ... 1
        #23                               // ... with com/example/internal/Impl
</pre>
                </div>
                <p>Read that against the nine lines of source that produced it, and every count has a visible cause:</p>
                <div class="hex-dump">
                    <pre>  module com.example.demo  --  the nine directives below:
      requires java.base;                          -> 1 requires, no flags
      requires transitive java.logging;           -> 2nd requires, ACC_TRANSITIVE
      exports com.example.api;                    -> 1st export, no target list
      exports com.example.internal                -> 2nd export, "to" count 1
              to com.example.friend;
      opens com.example.model;                    -> 1 opens, no target list
      uses com.example.api.Service;               -> 1 uses
      provides com.example.api.Service            -> 1 provides, "with" count 1
              with com.example.internal.Impl;
  -- end of module --
</pre>
                </div>
                <p>Several things fall out of the decoded values, and they are the interesting content of the concept.</p>
                <h3>The version string is shared, and the flags are a second field</h3>
                <p><strong>Both <code>requires</code> entries carry the same version index <code>#10</code> = <code>"26.0.1"</code></strong> &mdash; one <code>Utf8</code> for two references, the constant pool's dictionary doing its job on a field most formats would have inlined. And the second entry's <code>#11,20</code> is a <code>CONSTANT_Module</code> with flags <code>0x0020</code> = <code>ACC_TRANSITIVE</code>.</p>
                <p><strong>So a <code>requires</code> entry is three fields, not two:</strong> a module reference, a <code>u2</code> of flags, and a version string. The version is <em>not</em> part of the module name &mdash; it is a separate optional <code>Utf8</code>, and a module that specifies no version has <code>0</code> there. <strong>A version number being a plain string rather than a comparable value is a deliberate and slightly surprising choice</strong>, and the reason is that Java versions are strings in the specification too: <code>26.0.1</code> and <code>26</code> are both legal and are not compared numerically.</p>
                <h3>exports and opens, and the target lists</h3>
                <p>The two <code>exports</code> entries differ in a field that is easy to miss: the first has <code>0</code> target count and the second has <code>1</code>, naming <code>com.example.friend</code>. <strong>An export is public to everyone by default and restricted only by an explicit target list</strong> &mdash; the <code>to</code> clause narrows it. There is no "exported to nobody" form; that is what <code>opens</code> is for.</p>
                <p>And the distinction between <code>exports</code> and <code>opens</code> is <strong>compile-time versus run-time access</strong>. <code>exports</code> makes a package's types nameable in source &mdash; other modules can <code>import</code> them and call their public members. <code>opens</code> makes a package's types reflectable &mdash; <code>Class.forName</code> works and <code>setAccessible</code> can reach non-public members, but you still cannot name the type in source. <strong>Two keywords, one attribute, and a distinction that exists because Java has compile-time access and reflective access as separate mechanisms.</strong> A framework doing dependency injection <code>opens</code> a package; a library that wants to be used <code>exports</code> one.</p>
                <h3>uses and provides: the service declaration</h3>
                <p>The last two sections are the service loader, and they are the only parts of the attribute that name <em>classes</em> rather than modules or packages &mdash; both use <code>CONSTANT_Class</code> indices, not the new tags:</p>
                <div class="hex-dump">
                    <pre>  uses:      #21 -> com/example/api/Service      (a CONSTANT_Class)
  provides:  #21 -> com/example/api/Service with ... 1
                       #23 -> com/example/internal/Impl

  and note: the SAME index #21 appears in both sections, because
  both are pointing at the same Class pool entry. The service type
  is stored once.
</pre>
                </div>
                <p><strong>That is the point of the pairing.</strong> A module <code>uses</code> a service to declare that it looks one up, and <code>provides</code> one to declare that it supplies an implementation. The runtime's service loader pairs them by <em>type name</em>, not by identity, so the two lists in two different files meet at a string. <strong>A cross-file correspondence resolved by name</strong> &mdash; and the same shape as a <a href="/courses/elf/lessons/symbol-table">dynamic ELF symbol</a> being resolved by name across objects, with a different failure mode if the names do not match.</p>
                <p>Which gives the honest limit of the whole feature. <strong>Module boundaries are enforced by the launcher, not by the class file.</strong> A class file carries its module's declarations, but those declarations mean nothing on a plain class path, where everything sees everything. That is the same two-mode architecture as the rest of Underlayer, and it is worth naming: <strong>the attribute is a declaration of intent that a specific runtime configuration chooses to honour.</strong> Run the same class on the class path and the module system is inert &mdash; which is exactly how the migration was staged, and why every module-aware library also works without it.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Why this feature needed new pool tags when <a href="/courses/jvm/lessons/jvm-sealed">sealing</a> was happy with a list of class indices &mdash; and the answer is about what the names are <em>for</em>.</p>
                <div class="formula">
  Sealed: PermittedSubclasses -> a list of Class indices
          because a permitted subclass must RESOLVE to a class.
          A Class entry has the internal name the loader needs.

  Module: requires  -> CONSTANT_Module
          exports    -> CONSTANT_Package
          uses       -> CONSTANT_Class

  the difference: a module name "com.example.demo" is NOT a class
  name. Nothing loads it. It is matched against other modules'
  names, in configuration files and on the command line.

  so the Module and Package tags mark names that are read and
  compared but never resolved to a Class. That is a genuinely
  different kind of name, and giving it a different tag keeps
  CONSTANT_Class meaning exactly one thing.
</div>
                <p>And the payoff of that choice is visible in this course's own tooling. The `java.lang.classfile` API added in Java 22 <strong>models these as distinct types</strong> &mdash; a <code>ModuleEntry</code> and a <code>PackageEntry</code>, distinct from <code>ClassEntry</code> &mdash; so a reader using the standard API cannot confuse them even by accident. <strong>A well-chosen pool tag becomes a type in every API built on top of it</strong>, and a conflated one becomes a permanent ambiguity that every consumer has to work around.</p>
                <p>Compare <a href="/courses/elf/lessons/elf-identification">ELF's <code>e_type</code></a> and <a href="/courses/pe/lessons/pe-optional-header">PE's characteristics</a>: both formats have a "what kind of thing is this" field, and both added values to it over time &mdash; <code>ET_DYN</code> and <code>ET_CORE</code> in ELF, the relocation-stripped flag in PE. <strong>The class file's answer was to add tags rather than flag values, which is the more expensive choice up front and the cheaper one forever</strong>, because a new tag cannot be confused with an old one and a new flag value can be silently mistaken for a combination of existing bits by a reader that does not know it. A reader from 1997 reading a tag it does not know skips it; a reader from 1997 reading an unknown flag value still renders it, and the <code>InnerClasses</code> <code>0x0008</code> problem from <a href="/courses/jvm/lessons/jvm-inner-classes">Module 3</a> is exactly that failure.</p>
                <p>The final point is the one that makes this concept more than a structure walk. <strong>A class file that declares modules is 370 bytes and describes an entire library's public surface</strong> &mdash; what it requires, what it exposes, what it reflects on, what it consumes and provides &mdash; in a form a machine can check. Before this, none of that was in the file; it lived in a build tool's configuration and in a convention about directory layout. <strong>The module feature did not add runtime capability so much as move a declaration from prose into bytes</strong>, and every other feature in this course has been a version of the same move: record components, permitted subclasses, enum constants, lambda targets. The format's thirty-year pattern is that each language feature eventually arrives as a structure the machine can read rather than a convention it can only hope for.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ javap -v -p out/module-info.class
$ python3 courses/jvm/assets/samples/crosscheck.py classes/module-info.class</code></pre>
                <ul>
                    <li><strong>Find the "Unknown" tags yourself.</strong> Dump any <code>module-info.class</code> with <code>javap -v</code> and grep for <code>Unknown</code>. <strong>Then decode the same pool with the JDK's own API</strong> &mdash; <code>Cf.java</code> in this course's samples does it &mdash; and see <code>Module</code> and <code>Package</code> where <code>javap</code> gave up on naming them. Two readers, one structure, one label.</li>
                    <li><strong>Count the two new tags against the old ones.</strong> This 370-byte file has 24 pool entries: 5 <code>Utf8</code>, 2 <code>Class</code>, 1 <code>Module</code>, 7 <code>Package</code>, 1 more <code>Module</code>. <strong>Over a third of the pool exists only to name modules and packages</strong> &mdash; and that is what the feature costs in a 370-byte file.</li>
                    <li><strong>Prove the version is a separate field.</strong> Give one <code>requires</code> a version and another none. <strong>The one without has <code>0</code> there, and it is not part of the name string</strong> &mdash; so a reader that appended the version to the name would be wrong. Print both name indices and both version indices.</li>
                    <li><strong>Flip <code>exports</code> to <code>opens</code> and see what changes.</strong> Same package, one keyword different. <strong>One attribute byte</strong>, and the difference between "other modules can name this type" and "reflection can reach this type" &mdash; a compile-time/run-time distinction in a single flag.</li>
                    <li><strong>Break the service pairing.</strong> Compile two modules where one's <code>provides</code> names a type the other does not <code>uses</code>. <strong>Nothing at load time complains</strong>, because the pairing is by name at resolution time. Compare a <a href="/courses/elf/lessons/symbol-table">dynamic ELF symbol</a> that never resolves &mdash; a link-time failure in a different phase.</li>
                    <li><strong>Run the same class on the class path.</strong> Take the module-aware jar and put it on a plain class path, then reflect on a package that was only <code>opens</code>ed. <strong>It throws <code>InaccessibleObjectException</code></strong> &mdash; which is the enforcement point, and it is in the runtime, not the class file.</li>
                    <li><strong>Add a sixth section and see what the spec requires.</strong> The <code>Module</code> attribute is positional with no section tags. <strong>Sketch what adding one would cost</strong> and compare with the <a href="/courses/jvm/lessons/jvm-attributes">attribute mechanism's</a> answer to the identical question. The contrast is the format's one inconsistency, and it is a deliberate one.</li>
                </ul>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: you run <code>javap -v</code> on a <code>module-info.class</code> and see <code>#6 = Unknown #7 // "com.example.demo"</code>. The same file's <code>uses</code> section shows <code>#21</code> as a <code>CONSTANT_Class</code>. What is the difference between the two entries, why does <code>javap</code> label one and not the other, and what would go wrong if <code>CONSTANT_Module</code> were encoded as a <code>CONSTANT_Class</code>?</p>
                <div class="quiz" id="quiz-jvm-modules-1">
                    <button class="quiz-option" data-correct="true" data-explain="Three separate things, and the third is the most interesting. A CONSTANT_Module names a module and its target is a Utf8 holding a dotted name that nothing ever resolves to a class -- it is only read and compared against other modules' names. A CONSTANT_Class names a class and its Utf8 holds an internal name that the loader resolves, which is why the uses section has to use Class and not Package: a service type has to be loadable. javap labels the Module one Unknown because the tool has no name for tag 19, which is a real and measurable fact about a disassembler shipped with every JDK for three decades -- it reads the structure correctly and resolves the Utf8 correctly, so it understands the data, but it has no label. The consequence of encoding a module as a Class would not be cosmetic. A CONSTANT_Class promises its name is an internal name that can be loaded, and a module name is not, so any tool that followed the promise would attempt a class load for com.example.demo, fail, and have to special-case modules. Worse, the tag would then mean three things -- class, module, package -- and every reader and every API built on the pool would need the ambiguity resolved by convention. The JDK's own classfile API avoids exactly that by modelling these as separate entry types, so a well-chosen tag becomes a type that consumers cannot confuse." onclick="checkQuiz('quiz-jvm-modules-1', this)"><code>CONSTANT_Module</code> names a module &mdash; a dotted identifier that is read and compared but never resolved to a class, while <code>CONSTANT_Class</code> names a class whose internal name the loader does resolve. <code>javap</code> says <code>Unknown</code> because it has no label for tag 19. Encoding a module as a <code>Class</code> would break the promise that a <code>Class</code> name is loadable, and would make one tag mean three things</button>
                    <button class="quiz-option" data-correct="false" data-explain="This is close and the inversion is the whole point: a module name is the one that is never resolved, which is exactly why it needed its own tag. A CONSTANT_Class's Utf8 is an internal name -- slashes, not dots -- because the loader resolves it to a Class object. A module name is dotted, human-facing, and is only ever compared against other module names in configuration and on the command line; nothing loads it. So if a module were encoded as a Class, the promise the tag makes would be false, and a conforming tool that tried to load com.example.demo would fail. That is the substantive reason for the separate tags and it is the opposite of what this answer states. The part about javap is right, and it is worth noting separately that a tool can read a structure correctly while lacking a label for it -- the Utf8 resolves, so the data is understood, only the name is missing." onclick="checkQuiz('quiz-jvm-modules-1', this)"><code>CONSTANT_Module</code> names a module and is resolved to a <code>java.lang.Module</code> at load time, unlike a <code>CONSTANT_Class</code> which is only a name. <code>javap</code> says <code>Unknown</code> because the tag is newer than the tool, and encoding a module as a <code>Class</code> would be harmless since both are just name references</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>You are building a dependency-analysis tool. It reads every class file, collects the module each one belongs to from its <code>Module</code> attribute, and builds a graph of module dependencies to detect cycles. On a codebase built with modules it works. On the class path &mdash; where most dependencies actually live &mdash; it reports every class as belonging to the unnamed module and then produces a single-node graph, and the team concludes the project has no cycles when it has three. What is the tool assuming, and how should it handle the two cases without making the module-aware path worse?</p>
                <div class="quiz" id="quiz-jvm-modules-2">
                    <button class="quiz-option" data-correct="true" data-explain="The tool is assuming the module declaration is present, and it is not a universal declaration -- it is a declaration in a class file that only means anything to a runtime configured to honour it. A class on the class path has no Module attribute at all, so its module is not the unnamed module in the sense of a value read from the file; there is simply no module information available, and the tool is confusing an absence with a default. The fix is to make the absence explicit rather than to invent a value for it: represent 'no module' as a distinct state, and report the class path case as 'module information unavailable' rather than as a single anonymous module. That is a one-line change in the model and it is the difference between an accurate report and a confident wrong one. The constraint about not making the module-aware path worse is the real design point, because the tempting shortcut is to synthesise a pseudo-module per class path entry, which would make the graph look populated and would be worse than reporting nothing: the synthesised boundaries would be arbitrary and the cycle report would then be actively misleading rather than merely empty. The general habit is to distinguish the three states a format leaves open -- present with a value, present with a sentinel, and absent -- and never to collapse the last two, because a format's absence is a designed case and defaults are usually the tool's invention rather than the format's." onclick="checkQuiz('quiz-jvm-modules-2', this)">It is assuming the <code>Module</code> attribute is present, and on the class path it is absent rather than empty. Make 'no module information' a distinct state and report it as unavailable, instead of collapsing absence into a single unnamed module &mdash; and do not synthesise per-jar pseudo-modules, which would trade an empty graph for a confidently wrong one</button>
                    <button class="quiz-option" data-correct="false" data-explain="This misdiagnoses the failure in a way that produces a worse tool. The class path case is not a name-format problem at all -- a jar built without a module declaration contains no module information whatsoever, so there is no dotted name to normalise and no internal name to convert. The tool is not seeing the right kind of name, it is seeing no name. The two-mode aspect is real and worth stating -- the attribute is a declaration of intent that a particular runtime configuration honours, and it is inert on the class path -- but the consequence is that the tool must handle an absent field, not reformat a present one. The tell is the symptom: if the graph had one node per jar with a malformed name in it, the report would show garbage labels. It shows a single node, which means everything resolved to the same value, which means nothing was read at all." onclick="checkQuiz('quiz-jvm-modules-2', this)">The tool is resolving module names as internal names, since a <code>CONSTANT_Class</code> name uses slashes and a module name uses dots, so it is parsing one as the other. It should read the <code>CONSTANT_Module</code> entry and keep the dotted form for graph keys</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: a format leaves three states open &mdash; present with a value, present with a sentinel, and absent. Never collapse the last two. A default is usually the tool's invention, not the format's.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Modules are <a href="/courses/dwarf/lessons/dwarf-versions">an import mechanism</a>, and the closest comparison is one this course has already established: DWARF's unit-level model. A DWARF unit declares its own dependencies &mdash; which unit it was compiled from, its producer, its language &mdash; and a consumer that has not got the unit it needs cannot proceed. <strong>Both put a dependency declaration in the artefact so the consumer can check it, rather than leaving it to a build system's knowledge.</strong> The differences are instructive too: DWARF units are not enforced at load, and a DWARF consumer that skips a missing unit often still works.</p>
                <p>The <code>exports</code>/<code>opens</code> distinction has a closer relative in <a href="/courses/pe/lessons/pe-data-directories">the PE's exports directory</a> and in <a href="/courses/elf/lessons/symbol-table">an ELF symbol table</a>: all three are a list of names with an address or a target, and all three are declarations of what a consumer may reach. <strong>Where they part company is the enforcement point</strong> &mdash; a PE export table is honoured by the loader because there is no other way to find the code, while a module's <code>exports</code> is honoured by a launcher that could be configured to ignore it. The Java case is the unusual one: <strong>a declaration of encapsulation that is optional to enforce</strong>, which is what made the migration possible and is also why it has been called advisory.</p>
                <p>The positional five-section <code>Module</code> attribute is the format's one departure from its own philosophy, and comparing it to <a href="/courses/wasm/lessons/wasm-objects">a WebAssembly custom section</a> shows the cost. A custom section is name, length, contents &mdash; fully extensible, and adding a new kind costs nothing. The <code>Module</code> attribute is five positional sections with fixed order, so <strong>a new kind of module directive would require a new major version</strong>, because there is nowhere to put a sixth count. That is a real limitation, and it is the direct consequence of choosing positional layout for a feature that was still finding its shape. The format's own answer to that problem is the attribute mechanism, and this attribute chose not to use it.</p>
                <p>And the <code>uses</code>/<code>provides</code> pairing is a cross-file correspondence resolved by name, which makes it the third instance in this course of that pattern: an <a href="/courses/elf/lessons/symbol-table">ELF dynamic symbol</a> matched by name across objects, a <a href="/courses/coff/lessons/coff-weak-externals">COFF weak external</a> resolved by the linker, and now a Java service type matched across module files. <strong>Resolving by name is what lets independently-compiled things find each other, and the price is that a rename on one side silently breaks the match</strong> unless something checks both directions. Services add the <code>uses</code> half precisely so the consumer's intent is on the record too &mdash; which is the same two-sided declaration as the nest and the sealed hierarchy, and the same reason it exists.</p>
                <p>One last connection, and it is the one that ties the module to the course's own architecture. <a href="/courses/jvm/lessons/jvm-attributes">The escape hatch</a> exists so old readers survive new writers. <code>invokedynamic</code> exists so new writers need no new opcodes. <strong>Modules are the case where the format added something with no escape hatch at all</strong> &mdash; a positional attribute, a new class flag, and two new pool tags &mdash; which is what happens when a feature is big enough to be worth a version number. It is the right answer and it is also the only place in this course where the format's two strategies &mdash; additive and versioned &mdash; are both visible in one design, because <code>CONSTANT_Module</code> is additive while the attribute's layout is versioned.</p>
                <p>Last: <a href="/courses/jvm/lessons/jvm-versions">the version history</a>, which is where all of this gets put in order &mdash; what each major version added, and the pattern behind thirty years of additions.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/jvm/lessons/jvm-invokedynamic">Previous: invokedynamic and Bootstraps</a></span>
                <span><a href="/courses/jvm/lessons/jvm-versions">Next: Version History</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
