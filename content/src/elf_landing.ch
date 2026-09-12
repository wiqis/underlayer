// ELF Course — Landing Page
// Shows the course structure and links to each concept.
// Uses #html, #css, #js macros for all markup.

public namespace underlayer_content {

using std::string

using std::string_view

public func render_elf_landing() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Executable and Linkable Format — Underlayer")
    page.appendTitle(&title)

    #html {
        <div class="course-landing">
            <div class="course-header">
                <h1>Executable and Linkable Format</h1>
                <p class="course-description">A deep dive into the ELF binary format — headers, sections, segments, symbols, relocations, and dynamic linking.</p>
                <div class="course-meta">
                    <span class="meta-item">4 modules</span>
                    <span class="meta-item">12 concepts</span>
                    <span class="meta-item">Beginner-friendly</span>
                </div>
            </div>

            <div class="module-list">
                <div class="module">
                    <h2>Module 1: Fundamentals</h2>
                    <p>Bytes, binary representation, and file layout.</p>
                    <ul class="concept-list">
                        <li><a href="/courses/elf/lessons/bytes">Bytes and Binary</a></li>
                        <li><a href="/courses/elf/lessons/binary-representation">Binary Representation</a></li>
                        <li><a href="/courses/elf/lessons/file-layout">File Layout</a></li>
                    </ul>
                </div>

                <div class="module">
                    <h2>Module 2: ELF Header</h2>
                    <p>The ELF identification and header structure.</p>
                    <ul class="concept-list">
                        <li><a href="/courses/elf/lessons/elf-identification">ELF Identification</a></li>
                        <li><a href="/courses/elf/lessons/elf-header-fields">ELF Header Fields</a></li>
                        <li><a href="/courses/elf/lessons/entry-point">Entry Point</a></li>
                    </ul>
                </div>

                <div class="module">
                    <h2>Module 3: Program Headers</h2>
                    <p>How the loader maps segments into memory.</p>
                    <ul class="concept-list">
                        <li><a href="/courses/elf/lessons/program-header-table">Program Header Table</a></li>
                        <li><a href="/courses/elf/lessons/segment-types">Segment Types</a></li>
                        <li><a href="/courses/elf/lessons/memory-mapping">Memory Mapping</a></li>
                    </ul>
                </div>

                <div class="module">
                    <h2>Module 4: Sections</h2>
                    <p>The sections that make up an ELF file.</p>
                    <ul class="concept-list">
                        <li><a href="/courses/elf/lessons/section-header-table">Section Header Table</a></li>
                        <li><a href="/courses/elf/lessons/common-sections">Common Sections</a></li>
                        <li><a href="/courses/elf/lessons/section-vs-segment">Section vs Segment</a></li>
                    </ul>
                </div>
            </div>
        </div>
    }

    #css {
        .course-landing { max-width: 800px; margin: 0 auto; padding: 2rem; font-family: system-ui, sans-serif; }
        .course-header { margin-bottom: 2rem; }
        .course-header h1 { font-size: 2rem; margin-bottom: 0.5rem; }
        .course-description { font-size: 1.1rem; color: #4b5563; margin-bottom: 1rem; }
        .course-meta { display: flex; gap: 1rem; }
        .meta-item { padding: 0.25rem 0.75rem; background: #f3f4f6; border-radius: 9999px; font-size: 0.875rem; color: #374151; }
        .module-list { display: flex; flex-direction: column; gap: 1.5rem; }
        .module { padding: 1.5rem; border: 1px solid #e5e7eb; border-radius: 8px; }
        .module h2 { font-size: 1.25rem; margin-bottom: 0.5rem; }
        .module p { color: #6b7280; margin-bottom: 1rem; }
        .concept-list { list-style: none; padding: 0; margin: 0; }
        .concept-list li { padding: 0.5rem 0; border-bottom: 1px solid #f3f4f6; }
        .concept-list li:last-child { border-bottom: none; }
        .concept-list a { color: #3b82f6; text-decoration: none; }
        .concept-list a:hover { text-decoration: underline; }
    }

    return page.toString()
}
}
