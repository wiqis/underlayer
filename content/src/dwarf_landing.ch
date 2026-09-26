// DWARF Course — Landing Page (static build).
// Shows the course structure and links to each concept.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_dwarf_landing() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    page.injectDefaultComponentsTheme()
    var title = std::string_view("DWARF Debugging Data Format — Underlayer")
    page.appendTitle(&title)

    #html {
        <a href="#main-content" class="skip-link">Skip to content</a>
        <div class="navbar">
            <div class="nav-inner">
                <a href="/" class="nav-brand">Underlayer</a>
                <div class="nav-links">
                    <a href="/" class="nav-link">Home</a>
                    <a href="/courses/dwarf" class="nav-link active">Courses</a>
                    <a href="/dashboard" class="nav-link">Dashboard</a>
                    <a href="/review" class="nav-link">Review</a>
                    <a href="/progress" class="nav-link">Progress</a>
                </div>
            </div>
        </div>

        <div class="course-landing" id="main-content">
            <div class="course-header">
                <h1>DWARF &mdash; The Debugging Data Format</h1>
                <p class="course-description">The file format that takes a program apart and puts the source back. DWARF is how a debugger turns the address <code>0x1154</code> into "line 15 of shape.c", and it is the companion to the ELF, PE and Mach-O courses you have already met: those teach you how a binary is loaded and run, this one teaches how it is read.</p>
                <div class="course-meta">
                    <span class="meta-item">5 modules</span>
                    <span class="meta-item">23 concepts</span>
                    <span class="meta-item">Intermediate</span>
                    <span class="meta-item">~450 min</span>
                </div>
            </div>

            <div class="callout callout-tip">
                <strong>What you need first.</strong> This course assumes you can read an ELF section header table and you are comfortable with hexadecimal and little-endian integers. If either is shaky, revisit <a href="/courses/elf/lessons/section-header-table">The ELF Section Header Table</a> and <a href="/courses/elf/lessons/binary-representation">Bytes and Binary</a> first &mdash; they take about twenty minutes together and make everything below much cheaper.
            </div>

            <div class="callout callout-warn">
                <strong>Everything here is verified against a real binary.</strong> Every hex dump, offset, field size and decoded value in this course was produced by compiling one C file on this machine, slicing the debug sections out of the resulting ELF, decoding them with an independent parser, and then requiring that parser to agree with <code>readelf</code> field by field. No example was written from memory. Where a number could not be verified, it is marked rather than guessed.
            </div>

            <div class="module-list">
                <div class="module">
                    <h2>Module 1: Why Debug Info Exists</h2>
                    <p>What problem DWARF solves, which sections it produces, who reads them, and why the version number is the first thing a parser must check.</p>
                    <ul class="concept-list">
                        <li><a href="/courses/dwarf/lessons/dwarf-intro">Why DWARF Exists</a> <span class="concept-time">14 min</span></li>
                        <li><a href="/courses/dwarf/lessons/dwarf-sections">The .debug_* Sections</a> <span class="concept-time">16 min</span></li>
                        <li><a href="/courses/dwarf/lessons/dwarf-versions">DWARF 2, 3, 4 and 5</a> <span class="concept-time">18 min</span></li>
                    </ul>

                <div class="module">
                    <h2>Module 5: The Format on Other Inputs</h2>
                    <p>Everything before this module read one version of DWARF, from one toolchain, on one
                    machine &mdash; which is the newest version rather than the most common one. This module
                    produces the other configurations and puts them beside it: a version from before the
                    version 5 restructure, a second kind of compilation unit, the parts of a DIE tree that
                    describe calls that already returned, and the unwind section that is not the one the
                    frames concept decoded.</p>
                    <ul class="concept-list">
                        <li><a href="/courses/dwarf/lessons/dwarf-v4">DWARF 4 in Practice</a> <span class="concept-time">20 min</span></li>
                        <li><a href="/courses/dwarf/lessons/dwarf-type-units">Type Units</a> <span class="concept-time">21 min</span></li>
                        <li><a href="/courses/dwarf/lessons/dwarf-call-sites">Call Sites</a> <span class="concept-time">22 min</span></li>
                        <li><a href="/courses/dwarf/lessons/dwarf-frame">The Other Unwind Section</a> <span class="concept-time">21 min</span></li>
                    </ul>
                    <p class="module-note">The type-units concept contains a finding worth reading for even if you
                    skip the rest: <code>readelf</code> prints only eight of a type signature's sixteen bytes, and
                    the other eight are not all hash material.</p>
                </div>
                </div>

                <div class="module">
                    <h2>Module 2: The Line Number Program</h2>
                    <p>The address-to-source mapping, taken apart byte by byte: the header, the file tables, the twelve standard opcodes, the special-opcode arithmetic, and the lookup a debugger actually performs.</p>
                    <ul class="concept-list">
                        <li><a href="/courses/dwarf/lessons/dwarf-line-header">The .debug_line Header</a> <span class="concept-time">20 min</span></li>
                        <li><a href="/courses/dwarf/lessons/dwarf-file-tables">Directory and File Tables</a> <span class="concept-time">17 min</span></li>
                        <li><a href="/courses/dwarf/lessons/dwarf-standard-opcodes">The Standard Opcodes</a> <span class="concept-time">16 min</span></li>
                        <li><a href="/courses/dwarf/lessons/dwarf-special-opcodes">The Special Opcodes</a> <span class="concept-time">20 min</span></li>
                        <li><a href="/courses/dwarf/lessons/dwarf-address-to-line">From Rows to Source Lines</a> <span class="concept-time">18 min</span></li>
                    </ul>
                </div>

                <div class="module">
                    <h2>Module 3: DIEs, Types, Scopes, Locations and Frames</h2>
                    <p>The other half of DWARF: everything a debugger needs besides a line number. The tree that describes types, the types themselves, where variables live, how the stack is unwound, and the indexes that make finding any of it cheap.</p>
                    <ul class="concept-list">
                        <li><a href="/courses/dwarf/lessons/dwarf-dies">The DIE Tree</a> <span class="concept-time">20 min</span></li>
                        <li><a href="/courses/dwarf/lessons/dwarf-types">Types and Type Chains</a> <span class="concept-time">22 min</span></li>
                        <li><a href="/courses/dwarf/lessons/dwarf-scopes">Scopes and Inlining</a> <span class="concept-time">21 min</span></li>
                        <li><a href="/courses/dwarf/lessons/dwarf-locations">Location Expressions</a> <span class="concept-time">21 min</span></li>
                        <li><a href="/courses/dwarf/lessons/dwarf-frames">Call Frame Information</a> <span class="concept-time">22 min</span></li>
                        <li><a href="/courses/dwarf/lessons/dwarf-split">Split DWARF</a> <span class="concept-time">19 min</span></li>
                        <li><a href="/courses/dwarf/lessons/dwarf-lookup">Finding Things Without Reading Everything</a> <span class="concept-time">18 min</span></li>
                    </ul>
                </div>

                <div class="module">
                    <h2>Module 4: Location Lists, Portability and Packages</h2>
                    <p>Three tables the first three modules only implied, and the two questions that decide whether
                    a reader works on anything but this machine. Where is a <em>value</em> in the code, and where is the
                    <em>code</em> &mdash; both as lists of ranges. Then portability, measured rather than assumed: the same
                    source built four ways. Then the package format, and an index that lets a debugger skip a hundred files.</p>
                    <ul class="concept-list">
                        <li><a href="/courses/dwarf/lessons/dwarf-loclists">Location Lists</a> <span class="concept-time">24 min</span></li>
                        <li><a href="/courses/dwarf/lessons/dwarf-rnglists">Range Lists</a> <span class="concept-time">19 min</span></li>
                        <li><a href="/courses/dwarf/lessons/dwarf-portability">Same Source, Different Target</a> <span class="concept-time">21 min</span></li>
                        <li><a href="/courses/dwarf/lessons/dwarf-packages">Packages</a> <span class="concept-time">20 min</span></li>
                    </ul>
                    <p class="module-note">The <code>.debug_loclists</code> entry carries a warning worth reading first: the two
                    reference readers on this machine disagree about that section's encoding, and the concept shows how the byte
                    offsets settle it.</p>
                </div>
            </div>

            <div class="course-footer-note">
                <p>Every example in this course comes from a single 18-line C file compiled with <code>gcc -gdwarf-5 -O0</code>. The <a href="/courses/elf/lessons/memory-mapping">ELF memory mapping</a> course explains the addresses; this one explains what is recorded about them.</p>
            </div>
        </div>
    }

    #css {
        body { font-family: system-ui, -apple-system, sans-serif; line-height: 1.7; margin: 0; color: #111827; background: #ffffff; }
        .skip-link { position: absolute; left: -9999px; }
        .skip-link:focus { left: 1rem; top: 1rem; background: #ffffff; padding: 0.5rem 0.75rem; border: 2px solid #3b82f6; z-index: 100; }
        .navbar { background: #111827; color: #ffffff; padding: 0.75rem 1rem; }
        .nav-inner { max-width: 900px; margin: 0 auto; display: flex; align-items: center; gap: 1.5rem; }
        .nav-brand { color: #ffffff; font-weight: 700; text-decoration: none; }
        .nav-links { display: flex; gap: 1rem; margin-left: auto; }
        .nav-link { color: #d1d5db; text-decoration: none; font-size: 0.9rem; }
        .nav-link:hover, .nav-link.active { color: #ffffff; text-decoration: underline; }
        .course-landing { max-width: 900px; margin: 0 auto; padding: 2rem 1.5rem 4rem; }
        .course-header h1 { font-size: 2rem; margin: 0 0 0.5rem; }
        .course-description { color: #4b5563; font-size: 1.05rem; }
        .course-meta { display: flex; flex-wrap: wrap; gap: 0.75rem; margin: 1rem 0 1.5rem; }
        .meta-item { background: #f3f4f6; border: 1px solid #e5e7eb; border-radius: 999px; padding: 0.2rem 0.75rem; font-size: 0.8rem; color: #374151; }
        .callout { padding: 0.85rem 1rem; margin: 1.25rem 0; border-radius: 6px; font-size: 0.95rem; }
        .callout-tip { background: #eff6ff; border-left: 4px solid #3b82f6; }
        .callout-warn { background: #fffbeb; border-left: 4px solid #d97706; }
        .module-list { display: flex; flex-direction: column; gap: 1.75rem; margin-top: 2rem; }
        .module h2 { font-size: 1.2rem; margin: 0 0 0.35rem; }
        .module > p { color: #4b5563; margin: 0 0 0.5rem; }
        .concept-list { list-style: none; padding: 0; margin: 0.5rem 0 0; }
        .concept-list li { padding: 0.5rem 0; border-bottom: 1px solid #e5e7eb; display: flex; justify-content: space-between; gap: 1rem; align-items: baseline; }
        .concept-list li:last-child { border-bottom: none; }
        .concept-list a { color: #2563eb; text-decoration: none; }
        .concept-list a:hover { text-decoration: underline; }
        .concept-time { color: #6b7280; font-size: 0.85rem; white-space: nowrap; }
        .module-planned { opacity: 0.85; }
        .module-planned .concept-list li { color: #6b7280; }
        .module-note { font-size: 0.9rem; color: #6b7280; font-style: italic; }
        .course-footer-note { margin-top: 2.5rem; padding-top: 1.25rem; border-top: 1px solid #e5e7eb; color: #4b5563; font-size: 0.95rem; }
        code { background: #f3f4f6; padding: 0.15rem 0.4rem; border-radius: 4px; font-family: ui-monospace, monospace; font-size: 0.9em; }
        @media (max-width: 640px) { .course-landing { padding: 1.5rem 1rem 3rem; } .nav-links { display: none; } }
    }

    return page.toString()
}
}
