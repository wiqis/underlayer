// DWARF Course - Build entry point
// Renders all concept pages to output/ directory.

public func main() : int {
    course_writer::ensure_output()
    println(`Rendering DWARF course pages...`)

    // Module 1: Why Debug Info Exists
    var html = underlayer_content::render_dwarf_intro()
    course_writer::write_page("output/dwarf-intro.html", &html)
    println(`  -> dwarf-intro.html`)

    html = underlayer_content::render_dwarf_sections()
    course_writer::write_page("output/dwarf-sections.html", &html)
    println(`  -> dwarf-sections.html`)

    html = underlayer_content::render_dwarf_versions()
    course_writer::write_page("output/dwarf-versions.html", &html)
    println(`  -> dwarf-versions.html`)

    // Module 2: The Line Number Program
    html = underlayer_content::render_dwarf_line_header()
    course_writer::write_page("output/dwarf-line-header.html", &html)
    println(`  -> dwarf-line-header.html`)

    html = underlayer_content::render_dwarf_file_tables()
    course_writer::write_page("output/dwarf-file-tables.html", &html)
    println(`  -> dwarf-file-tables.html`)

    html = underlayer_content::render_dwarf_standard_opcodes()
    course_writer::write_page("output/dwarf-standard-opcodes.html", &html)
    println(`  -> dwarf-standard-opcodes.html`)

    html = underlayer_content::render_dwarf_special_opcodes()
    course_writer::write_page("output/dwarf-special-opcodes.html", &html)
    println(`  -> dwarf-special-opcodes.html`)

    html = underlayer_content::render_dwarf_address_to_line()
    course_writer::write_page("output/dwarf-address-to-line.html", &html)
    println(`  -> dwarf-address-to-line.html`)

    // Module 3: DIEs, Types, Scopes, Locations and Frames
    html = underlayer_content::render_dwarf_dies()
    course_writer::write_page("output/dwarf-dies.html", &html)
    println(`  -> dwarf-dies.html`)

    html = underlayer_content::render_dwarf_types()
    course_writer::write_page("output/dwarf-types.html", &html)
    println(`  -> dwarf-types.html`)

    html = underlayer_content::render_dwarf_scopes()
    course_writer::write_page("output/dwarf-scopes.html", &html)
    println(`  -> dwarf-scopes.html`)

    html = underlayer_content::render_dwarf_locations()
    course_writer::write_page("output/dwarf-locations.html", &html)
    println(`  -> dwarf-locations.html`)

    html = underlayer_content::render_dwarf_frames()
    course_writer::write_page("output/dwarf-frames.html", &html)
    println(`  -> dwarf-frames.html`)

    html = underlayer_content::render_dwarf_split()
    course_writer::write_page("output/dwarf-split.html", &html)
    println(`  -> dwarf-split.html`)

    html = underlayer_content::render_dwarf_lookup()
    course_writer::write_page("output/dwarf-lookup.html", &html)
    println(`  -> dwarf-lookup.html`)


    // Module 4: Location Lists, Portability and Packages
    html = underlayer_content::render_dwarf_loclists()
    course_writer::write_page("output/dwarf-loclists.html", &html)
    println(`  -> dwarf-loclists.html`)

    html = underlayer_content::render_dwarf_rnglists()
    course_writer::write_page("output/dwarf-rnglists.html", &html)
    println(`  -> dwarf-rnglists.html`)

    html = underlayer_content::render_dwarf_portability()
    course_writer::write_page("output/dwarf-portability.html", &html)
    println(`  -> dwarf-portability.html`)

    html = underlayer_content::render_dwarf_packages()
    course_writer::write_page("output/dwarf-packages.html", &html)
    println(`  -> dwarf-packages.html`)


    // Module 5: The Format on Other Inputs
    html = underlayer_content::render_dwarf_v4()
    course_writer::write_page("output/dwarf-v4.html", &html)
    println(`  -> dwarf-v4.html`)

    html = underlayer_content::render_dwarf_type_units()
    course_writer::write_page("output/dwarf-type-units.html", &html)
    println(`  -> dwarf-type-units.html`)

    html = underlayer_content::render_dwarf_call_sites()
    course_writer::write_page("output/dwarf-call-sites.html", &html)
    println(`  -> dwarf-call-sites.html`)

    html = underlayer_content::render_dwarf_frame()
    course_writer::write_page("output/dwarf-frame.html", &html)
    println(`  -> dwarf-frame.html`)

    // Landing page
    html = underlayer_content::render_dwarf_landing()
    course_writer::write_page("output/index.html", &html)
    println(`  -> index.html`)

    println(`DWARF course: 23 concepts + landing page generated in output/`)
    return 0
}
