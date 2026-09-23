// underlayer_web — Nav search / quick jump (P2 7.1.10 command palette).
//
// Entries mirror render_concept() in helpers.ch. ELF and PE concepts are
// prefixed per course so palette URLs stay correct for both.
using std::string
using std::string_view

public namespace underlayer_web {

    public func handle_nav_search(req : &http::Request, res : *mut http::ResponseWriter) {
        var body = string("{\"entries\":[")
        body.append_view("{\"label\":\"Home\",\"url\":\"/\",\"kind\":\"page\"}")
        body.append_view(",{\"label\":\"Dashboard\",\"url\":\"/dashboard\",\"kind\":\"page\"}")
        body.append_view(",{\"label\":\"Review\",\"url\":\"/review\",\"kind\":\"page\"}")
        body.append_view(",{\"label\":\"Progress\",\"url\":\"/progress\",\"kind\":\"page\"}")

        append_elf_nav_entries(&raw body)
        append_pe_nav_entries(&raw body)
        append_macho_nav_entries(&raw body)

        body.append_view("]}")
        send_json_str(res, &raw body)
    }

    // 24 ELF concepts in course order.
    func append_elf_nav_entries(body : *string) {
        append_nav_entry(body, string("Bytes and Binary"), string("elf"), string("bytes"))
        append_nav_entry(body, string("Binary Representation"), string("elf"), string("binary-representation"))
        append_nav_entry(body, string("File Layout"), string("elf"), string("file-layout"))
        append_nav_entry(body, string("ELF Identification"), string("elf"), string("elf-identification"))
        append_nav_entry(body, string("ELF Header Fields"), string("elf"), string("elf-header-fields"))
        append_nav_entry(body, string("Entry Point"), string("elf"), string("entry-point"))
        append_nav_entry(body, string("Program Header Table"), string("elf"), string("program-header-table"))
        append_nav_entry(body, string("Segment Types"), string("elf"), string("segment-types"))
        append_nav_entry(body, string("Memory Mapping"), string("elf"), string("memory-mapping"))
        append_nav_entry(body, string("Section Header Table"), string("elf"), string("section-header-table"))
        append_nav_entry(body, string("Common Sections"), string("elf"), string("common-sections"))
        append_nav_entry(body, string("Section vs Segment"), string("elf"), string("section-vs-segment"))
        append_nav_entry(body, string("Symbol Table"), string("elf"), string("symbol-table"))
        append_nav_entry(body, string("Symbol Binding"), string("elf"), string("binding"))
        append_nav_entry(body, string("Symbol Visibility"), string("elf"), string("visibility"))
        append_nav_entry(body, string("Relocation Entries"), string("elf"), string("relocation-entries"))
        append_nav_entry(body, string("Relocation Types"), string("elf"), string("relocation-types"))
        append_nav_entry(body, string("Dynamic Relocations"), string("elf"), string("dynamic-relocations"))
        append_nav_entry(body, string("Dynamic Section"), string("elf"), string("dynamic-section"))
        append_nav_entry(body, string("Shared Libraries"), string("elf"), string("shared-libraries"))
        append_nav_entry(body, string("The Dynamic Linker"), string("elf"), string("ld-so"))
        append_nav_entry(body, string("The Kernel Loader"), string("elf"), string("loader"))
        append_nav_entry(body, string("Process Memory Layout"), string("elf"), string("memory-layout"))
        append_nav_entry(body, string("The Startup Sequence"), string("elf"), string("execution"))
    }

    // 24 PE concepts in course order.
    func append_pe_nav_entries(body : *string) {
        append_nav_entry(body, string("PE: Why PE Exists"), string("pe"), string("pe-intro"))
        append_nav_entry(body, string("PE: File Layout"), string("pe"), string("pe-file-layout"))
        append_nav_entry(body, string("PE: The COFF Heritage"), string("pe"), string("pe-coff-basics"))
        append_nav_entry(body, string("PE: The MS-DOS Header"), string("pe"), string("pe-dos-header"))
        append_nav_entry(body, string("PE: Signature and COFF Header"), string("pe"), string("pe-signature-coff"))
        append_nav_entry(body, string("PE: The Optional Header"), string("pe"), string("pe-optional-header"))
        append_nav_entry(body, string("PE: The Data Directories"), string("pe"), string("pe-data-directories"))
        append_nav_entry(body, string("PE: VA, RVA, and File Offset"), string("pe"), string("pe-addresses"))
        append_nav_entry(body, string("PE: Converting RVAs"), string("pe"), string("pe-rva-conversion"))
        append_nav_entry(body, string("PE: The Section Table"), string("pe"), string("pe-section-table"))
        append_nav_entry(body, string("PE: Common Sections"), string("pe"), string("pe-common-sections"))
        append_nav_entry(body, string("PE: Alignment"), string("pe"), string("pe-alignment"))
        append_nav_entry(body, string("PE: The Import Tables"), string("pe"), string("pe-imports"))
        append_nav_entry(body, string("PE: The Export Tables"), string("pe"), string("pe-exports"))
        append_nav_entry(body, string("PE: Delay-Load Imports"), string("pe"), string("pe-delay-loads"))
        append_nav_entry(body, string("PE: Base Relocations"), string("pe"), string("pe-base-relocations"))
        append_nav_entry(body, string("PE: Security Flags"), string("pe"), string("pe-security-flags"))
        append_nav_entry(body, string("PE: Load Configuration"), string("pe"), string("pe-load-config"))
        append_nav_entry(body, string("PE: Resource Directory"), string("pe"), string("pe-resources"))
        append_nav_entry(body, string("PE: Thread-Local Storage"), string("pe"), string("pe-tls"))
        append_nav_entry(body, string("PE: Exception Tables"), string("pe"), string("pe-exceptions"))
        append_nav_entry(body, string("PE: The Windows Loader"), string("pe"), string("pe-loader"))
        append_nav_entry(body, string("PE: Process Memory Layout"), string("pe"), string("pe-memory-layout"))
        append_nav_entry(body, string("PE: The Startup Sequence"), string("pe"), string("pe-execution"))
    }

    // 24 Mach-O concepts in course order.
    func append_macho_nav_entries(body : *string) {
        append_nav_entry(body, string("Mach-O: Why Mach-O Exists"), string("macho"), string("macho-intro"))
        append_nav_entry(body, string("Mach-O: File Layout"), string("macho"), string("macho-file-layout"))
        append_nav_entry(body, string("Mach-O: Magic Numbers"), string("macho"), string("macho-magic"))
        append_nav_entry(body, string("Mach-O: mach_header_64"), string("macho"), string("macho-header"))
        append_nav_entry(body, string("Mach-O: CPU Types"), string("macho"), string("macho-cputypes"))
        append_nav_entry(body, string("Mach-O: Universal Binaries"), string("macho"), string("macho-universal"))
        append_nav_entry(body, string("Mach-O: Load Command Area"), string("macho"), string("macho-load-commands"))
        append_nav_entry(body, string("Mach-O: LC_SEGMENT_64"), string("macho"), string("macho-segments"))
        append_nav_entry(body, string("Mach-O: Sections"), string("macho"), string("macho-sections"))
        append_nav_entry(body, string("Mach-O: Symbol Table"), string("macho"), string("macho-symtab"))
        append_nav_entry(body, string("Mach-O: Dynamic Symbol Table"), string("macho"), string("macho-dysymtab"))
        append_nav_entry(body, string("Mach-O: Relocation Entries"), string("macho"), string("macho-relocations"))
        append_nav_entry(body, string("Mach-O: Dynamic Libraries"), string("macho"), string("macho-dylibs"))
        append_nav_entry(body, string("Mach-O: Rebase and Bind Opcodes"), string("macho"), string("macho-dyld-info"))
        append_nav_entry(body, string("Mach-O: Export Trie"), string("macho"), string("macho-export-trie"))
        append_nav_entry(body, string("Mach-O: Chained Fixups"), string("macho"), string("macho-chained-fixups"))
        append_nav_entry(body, string("Mach-O: Entry Point"), string("macho"), string("macho-entry"))
        append_nav_entry(body, string("Mach-O: Build Versions and UUID"), string("macho"), string("macho-build-version"))
        append_nav_entry(body, string("Mach-O: Code Signing"), string("macho"), string("macho-code-signing"))
        append_nav_entry(body, string("Mach-O: Debug Info"), string("macho"), string("macho-debug-info"))
        append_nav_entry(body, string("Mach-O: Memory Hardening"), string("macho"), string("macho-hardening"))
        append_nav_entry(body, string("Mach-O: How dyld Loads"), string("macho"), string("macho-dyld"))
        append_nav_entry(body, string("Mach-O: Process Memory Layout"), string("macho"), string("macho-memory-layout"))
        append_nav_entry(body, string("Mach-O: The Startup Sequence"), string("macho"), string("macho-execution"))
    }

    // Append one concept entry (adds comma before every entry).
    func append_nav_entry(body : *string, label : string, course_id : string, concept_id : string) {
        body.append_view(",{\"label\":\"")
        body.append_string(&label)
        body.append_view("\",\"url\":\"/courses/")
        body.append_string(&course_id)
        body.append_view("/lessons/")
        body.append_string(&concept_id)
        body.append_view("\",\"kind\":\"concept\"}")
    }

}
