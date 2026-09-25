// DWARF Course - Build entry point
// Renders all concept pages to output/ directory.

public func main() : int {
    fs::mkdir("output")
    printf("Rendering DWARF course pages...\n")

    // Module 1: Why Debug Info Exists
    var html = underlayer_content::render_dwarf_intro()
    fs::write_text_file("output/dwarf-intro.html", html.data() as *u8, html.size())
    printf("  -> dwarf-intro.html\n")

    html = underlayer_content::render_dwarf_sections()
    fs::write_text_file("output/dwarf-sections.html", html.data() as *u8, html.size())
    printf("  -> dwarf-sections.html\n")

    html = underlayer_content::render_dwarf_versions()
    fs::write_text_file("output/dwarf-versions.html", html.data() as *u8, html.size())
    printf("  -> dwarf-versions.html\n")

    // Module 2: The Line Number Program
    html = underlayer_content::render_dwarf_line_header()
    fs::write_text_file("output/dwarf-line-header.html", html.data() as *u8, html.size())
    printf("  -> dwarf-line-header.html\n")

    html = underlayer_content::render_dwarf_file_tables()
    fs::write_text_file("output/dwarf-file-tables.html", html.data() as *u8, html.size())
    printf("  -> dwarf-file-tables.html\n")

    html = underlayer_content::render_dwarf_standard_opcodes()
    fs::write_text_file("output/dwarf-standard-opcodes.html", html.data() as *u8, html.size())
    printf("  -> dwarf-standard-opcodes.html\n")

    html = underlayer_content::render_dwarf_special_opcodes()
    fs::write_text_file("output/dwarf-special-opcodes.html", html.data() as *u8, html.size())
    printf("  -> dwarf-special-opcodes.html\n")

    html = underlayer_content::render_dwarf_address_to_line()
    fs::write_text_file("output/dwarf-address-to-line.html", html.data() as *u8, html.size())
    printf("  -> dwarf-address-to-line.html\n")

    // Module 3: DIEs, Types, Scopes, Locations and Frames
    html = underlayer_content::render_dwarf_dies()
    fs::write_text_file("output/dwarf-dies.html", html.data() as *u8, html.size())
    printf("  -> dwarf-dies.html\n")

    html = underlayer_content::render_dwarf_types()
    fs::write_text_file("output/dwarf-types.html", html.data() as *u8, html.size())
    printf("  -> dwarf-types.html\n")

    html = underlayer_content::render_dwarf_scopes()
    fs::write_text_file("output/dwarf-scopes.html", html.data() as *u8, html.size())
    printf("  -> dwarf-scopes.html\n")

    html = underlayer_content::render_dwarf_locations()
    fs::write_text_file("output/dwarf-locations.html", html.data() as *u8, html.size())
    printf("  -> dwarf-locations.html\n")

    html = underlayer_content::render_dwarf_frames()
    fs::write_text_file("output/dwarf-frames.html", html.data() as *u8, html.size())
    printf("  -> dwarf-frames.html\n")

    html = underlayer_content::render_dwarf_split()
    fs::write_text_file("output/dwarf-split.html", html.data() as *u8, html.size())
    printf("  -> dwarf-split.html\n")

    html = underlayer_content::render_dwarf_lookup()
    fs::write_text_file("output/dwarf-lookup.html", html.data() as *u8, html.size())
    printf("  -> dwarf-lookup.html\n")


    // Module 4: Location Lists, Portability and Packages
    html = underlayer_content::render_dwarf_loclists()
    fs::write_text_file("output/dwarf-loclists.html", html.data() as *u8, html.size())
    printf("  -> dwarf-loclists.html\n")

    html = underlayer_content::render_dwarf_rnglists()
    fs::write_text_file("output/dwarf-rnglists.html", html.data() as *u8, html.size())
    printf("  -> dwarf-rnglists.html\n")

    html = underlayer_content::render_dwarf_portability()
    fs::write_text_file("output/dwarf-portability.html", html.data() as *u8, html.size())
    printf("  -> dwarf-portability.html\n")

    html = underlayer_content::render_dwarf_packages()
    fs::write_text_file("output/dwarf-packages.html", html.data() as *u8, html.size())
    printf("  -> dwarf-packages.html\n")

    // Landing page
    html = underlayer_content::render_dwarf_landing()
    fs::write_text_file("output/index.html", html.data() as *u8, html.size())
    printf("  -> index.html\n")

    printf("DWARF course: 19 concepts + landing page generated in output/\n")
    return 0
}
