// ELF Course — Landing Page
// Shows the course structure and links to each concept.
// Uses #html, #css, #js macros for all markup.

using std::string
using std::string_view

public func render_elf_landing() : string {
    var page = HtmlPage()
    page.default_prepare()
    var title = std::string_view("Executable and Linkable Format — Underlayer")
    page.append_title(&title)

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
                        <li><a href="bytes.html">Bytes and Binary</a></li>
                        <li><a href="binary-representation.html">Binary Representation</a></li>
                        <li><a href="file-layout.html">File Layout</a></li>
                    </ul>
                </div>

                <div class="module">
                    <h2>Module 2: ELF Header</h2>
                    <p>The ELF identification and header structure.</p>
                    <ul class="concept-list">
                        <li><a href="elf-identification.html">ELF Identification</a></li>
                        <li><a href="elf-header-fields.html">ELF Header Fields</a></li>
                        <li><a href="entry-point.html">Entry Point</a></li>
                    </ul>
                </div>

                <div class="module">
                    <h2>Module 3: Program Headers</h2>
                    <p>How the loader maps segments into memory.</p>
                    <ul class="concept-list">
                        <li><a href="program-header-table.html">Program Header Table</a></li>
                        <li><a href="segment-types.html">Segment Types</a></li>
                        <li><a href="memory-mapping.html">Memory Mapping</a></li>
                    </ul>
                </div>

                <div class="module">
                    <h2>Module 4: Sections</h2>
                    <p>The sections that make up an ELF file.</p>
                    <ul class="concept-list">
                        <li><a href="section-header-table.html">Section Header Table</a></li>
                        <li><a href="common-sections.html">Common Sections</a></li>
                        <li><a href="section-vs-segment.html">Section vs Segment</a></li>
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

    return page.to_string()
}
