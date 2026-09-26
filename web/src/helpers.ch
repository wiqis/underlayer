// underlayer_web — Shared helpers.
// Public so other files in the module can use them.
using std::string
using std::string_view

public namespace underlayer_web {

    public func send_page(res : *mut http::ResponseWriter, page : *HtmlPage) {
        var ct = std::string_view("text/html; charset=utf-8")
        res.set_header_view(std::string_view("Content-Type"), &ct)
        var html = page.toString()
        var hv = html.to_view()
        res.write_view(&hv)
    }

    public func send_html(res : *mut http::ResponseWriter, html : *string) {
        var ct = std::string_view("text/html; charset=utf-8")
        res.set_header_view(std::string_view("Content-Type"), &ct)
        var hv = html.to_view()
        res.write_view(&hv)
    }

    public func send_json_str(res : *mut http::ResponseWriter, body : *string) {
        var ct = std::string_view("application/json")
        res.set_header_view(std::string_view("Content-Type"), &ct)
        var bv = body.to_view()
        res.write_view(&bv)
    }

    public func send_error(res : *mut http::ResponseWriter, status : uint, msg : &string) {
        res.status = status
        var ct = std::string_view("application/json")
        res.set_header_view(std::string_view("Content-Type"), &ct)
        var body = std::string("{\"error\":\"")
        body.append_string(msg)
        body.append_view("\"}")
        var bv = body.to_view()
        res.write_view(&bv)
    }

    public func sv_to_string(sv : *string_view) : string {
        var out = std::string()
        var i : size_t = 0
        while(i < sv.size()) { out.append(sv.get(i)); i = i + 1 }
        return out
    }

    public func read_body(req : *mut http::Request) : string {
        // Content-Length 0 (or absent) + not chunked = no body. The HTTP
        // server leaves Body.remaining as -1 in that case, which would block
        // forever on an empty POST (CL=0 is not treated as body_len > 0).
        if(req.body_len == 0u && !req.body.is_chunked()) { return std::string() }
        var buf : [8192]u8
        var out = std::string()
        while(true) {
            var n = req.body.read(&raw mut buf[0], 8192)
            if(n <= 0) { break }
            var i : size_t = 0
            while(i < (n as size_t)) { out.append(buf[i] as char); i = i + 1 }
        }
        return out
    }

    // HAT course concept ids. The HAT course lives in the same content module
    // as the ELF course, so ids are namespaced with a `hat-` prefix to stay
    // unique across courses.
    public func render_hat_concept(concept_id : *string) : string {
        var cid = concept_id.copy()
        var exam_overview_id = std::string("hat-exam-overview")
        var weightage_id = std::string("hat-weightage-strategy")
        var study_plan_id = std::string("hat-study-plan")
        var time_budget_id = std::string("hat-time-budget")
        var triage_id = std::string("hat-triage-and-guessing")
        var arithmetic_id = std::string("hat-arithmetic")
        var number_properties_id = std::string("hat-number-properties")
        var fractions_id = std::string("hat-fractions-decimals")
        var percentages_id = std::string("hat-percentages")
        var ratio_id = std::string("hat-ratio-proportion")
        var averages_id = std::string("hat-averages")
        var rates_id = std::string("hat-rates-speed-distance")
        var work_rate_id = std::string("hat-work-rate")
        var counting_id = std::string("hat-counting-probability")
        var algebra_id = std::string("hat-algebra")
        var geometry_id = std::string("hat-geometry")
        var data_prob_id = std::string("hat-data-probability")
        var quant_drill_id = std::string("hat-quant-drill")
        var vocabulary_id = std::string("hat-vocabulary")
        var synonyms_id = std::string("hat-synonyms-antonyms")
        var analogies_id = std::string("hat-analogies")
        var sentence_id = std::string("hat-sentence-completion")
        var paragraph_id = std::string("hat-paragraph-completion")
        var grammar_id = std::string("hat-grammar-errors")
        var grammar_agreement_id = std::string("hat-grammar-agreement")
        var prepositions_id = std::string("hat-prepositions-idioms")
        var reading_id = std::string("hat-reading-comprehension")
        var verbal_drill_id = std::string("hat-verbal-drill")
        var critical_id = std::string("hat-critical-reasoning")
        var cause_effect_id = std::string("hat-cause-effect")
        var deduction_id = std::string("hat-logic-deduction")
        var seating_id = std::string("hat-seating-arrangements")
        var ordering_id = std::string("hat-ordering-scheduling")
        var syllogisms_id = std::string("hat-syllogisms")
        var relations_id = std::string("hat-relations-and-directions")
        var coding_id = std::string("hat-coding-decoding")
        var data_sufficiency_id = std::string("hat-data-sufficiency")
        var data_interp_id = std::string("hat-data-interpretation")
        var series_id = std::string("hat-pattern-series")
        var analytical_drill_id = std::string("hat-analytical-drill")
        var mock_id = std::string("hat-mock-protocol")
        var error_log_id = std::string("hat-error-log")
        var score_targets_id = std::string("hat-score-targets")
        var exam_day_id = std::string("hat-exam-day")
        var physics_id = std::string("hat-physics-mechanics")
        var programming_id = std::string("hat-programming-fundamentals")
        var digital_id = std::string("hat-digital-logic")
        var diagnostic_id = std::string("hat-diagnostic-test")
        var exponents_id = std::string("hat-exponents-roots")
        var quadratics_id = std::string("hat-quadratic-equations")
        var sequences_id = std::string("hat-sequences")
        var mensuration_id = std::string("hat-mensuration")
        var coordinate_id = std::string("hat-coordinate-geometry")
        var word_problems_id = std::string("hat-word-problems")
        var profit_loss_id = std::string("hat-profit-loss-discount")
        var interest_id = std::string("hat-interest")
        var sentence_correction_id = std::string("hat-sentence-correction")
        var critical_reading_id = std::string("hat-critical-reading")
        var tenses_id = std::string("hat-grammar-tenses")
        var punctuation_id = std::string("hat-grammar-punctuation")
        var statement_assumption_id = std::string("hat-statement-assumption")
        var statement_conclusion_id = std::string("hat-statement-conclusion")
        var strong_weak_id = std::string("hat-strong-weak-arguments")
        var course_of_action_id = std::string("hat-course-of-action")
        var grouping_id = std::string("hat-grouping-puzzles")
        var network_id = std::string("hat-network-routing")
        var sets_venn_id = std::string("hat-sets-venn")
        var review_method_id = std::string("hat-review-method")
        var energy_id = std::string("hat-energy-management")

        if(cid.equals(&exam_overview_id)) { return underlayer_content::render_hat_exam_overview() }
        if(cid.equals(&weightage_id)) { return underlayer_content::render_hat_weightage_strategy() }
        if(cid.equals(&study_plan_id)) { return underlayer_content::render_hat_study_plan() }
        if(cid.equals(&time_budget_id)) { return underlayer_content::render_hat_time_budget() }
        if(cid.equals(&triage_id)) { return underlayer_content::render_hat_triage_and_guessing() }
        if(cid.equals(&arithmetic_id)) { return underlayer_content::render_hat_arithmetic() }
        if(cid.equals(&number_properties_id)) { return underlayer_content::render_hat_number_properties() }
        if(cid.equals(&fractions_id)) { return underlayer_content::render_hat_fractions_decimals() }
        if(cid.equals(&percentages_id)) { return underlayer_content::render_hat_percentages() }
        if(cid.equals(&ratio_id)) { return underlayer_content::render_hat_ratio_proportion() }
        if(cid.equals(&averages_id)) { return underlayer_content::render_hat_averages() }
        if(cid.equals(&rates_id)) { return underlayer_content::render_hat_rates_speed_distance() }
        if(cid.equals(&work_rate_id)) { return underlayer_content::render_hat_work_rate() }
        if(cid.equals(&counting_id)) { return underlayer_content::render_hat_counting_probability() }
        if(cid.equals(&algebra_id)) { return underlayer_content::render_hat_algebra() }
        if(cid.equals(&geometry_id)) { return underlayer_content::render_hat_geometry() }
        if(cid.equals(&data_prob_id)) { return underlayer_content::render_hat_data_probability() }
        if(cid.equals(&quant_drill_id)) { return underlayer_content::render_hat_quant_drill() }
        if(cid.equals(&vocabulary_id)) { return underlayer_content::render_hat_vocabulary() }
        if(cid.equals(&synonyms_id)) { return underlayer_content::render_hat_synonyms_antonyms() }
        if(cid.equals(&analogies_id)) { return underlayer_content::render_hat_analogies() }
        if(cid.equals(&sentence_id)) { return underlayer_content::render_hat_sentence_completion() }
        if(cid.equals(&paragraph_id)) { return underlayer_content::render_hat_paragraph_completion() }
        if(cid.equals(&grammar_id)) { return underlayer_content::render_hat_grammar_errors() }
        if(cid.equals(&grammar_agreement_id)) { return underlayer_content::render_hat_grammar_agreement() }
        if(cid.equals(&prepositions_id)) { return underlayer_content::render_hat_prepositions_idioms() }
        if(cid.equals(&reading_id)) { return underlayer_content::render_hat_reading_comprehension() }
        if(cid.equals(&verbal_drill_id)) { return underlayer_content::render_hat_verbal_drill() }
        if(cid.equals(&critical_id)) { return underlayer_content::render_hat_critical_reasoning() }
        if(cid.equals(&cause_effect_id)) { return underlayer_content::render_hat_cause_effect() }
        if(cid.equals(&deduction_id)) { return underlayer_content::render_hat_logic_deduction() }
        if(cid.equals(&seating_id)) { return underlayer_content::render_hat_seating_arrangements() }
        if(cid.equals(&ordering_id)) { return underlayer_content::render_hat_ordering_scheduling() }
        if(cid.equals(&syllogisms_id)) { return underlayer_content::render_hat_syllogisms() }
        if(cid.equals(&relations_id)) { return underlayer_content::render_hat_relations_and_directions() }
        if(cid.equals(&coding_id)) { return underlayer_content::render_hat_coding_decoding() }
        if(cid.equals(&data_sufficiency_id)) { return underlayer_content::render_hat_data_sufficiency() }
        if(cid.equals(&data_interp_id)) { return underlayer_content::render_hat_data_interpretation() }
        if(cid.equals(&series_id)) { return underlayer_content::render_hat_pattern_series() }
        if(cid.equals(&analytical_drill_id)) { return underlayer_content::render_hat_analytical_drill() }
        if(cid.equals(&mock_id)) { return underlayer_content::render_hat_mock_protocol() }
        if(cid.equals(&error_log_id)) { return underlayer_content::render_hat_error_log() }
        if(cid.equals(&score_targets_id)) { return underlayer_content::render_hat_score_targets() }
        if(cid.equals(&exam_day_id)) { return underlayer_content::render_hat_exam_day() }
        if(cid.equals(&physics_id)) { return underlayer_content::render_hat_physics_mechanics() }
        if(cid.equals(&programming_id)) { return underlayer_content::render_hat_programming_fundamentals() }
        if(cid.equals(&digital_id)) { return underlayer_content::render_hat_digital_logic() }
        if(cid.equals(&diagnostic_id)) { return underlayer_content::render_hat_diagnostic_test() }
        if(cid.equals(&exponents_id)) { return underlayer_content::render_hat_exponents_roots() }
        if(cid.equals(&quadratics_id)) { return underlayer_content::render_hat_quadratic_equations() }
        if(cid.equals(&sequences_id)) { return underlayer_content::render_hat_sequences() }
        if(cid.equals(&mensuration_id)) { return underlayer_content::render_hat_mensuration() }
        if(cid.equals(&coordinate_id)) { return underlayer_content::render_hat_coordinate_geometry() }
        if(cid.equals(&word_problems_id)) { return underlayer_content::render_hat_word_problems() }
        if(cid.equals(&profit_loss_id)) { return underlayer_content::render_hat_profit_loss_discount() }
        if(cid.equals(&interest_id)) { return underlayer_content::render_hat_interest() }
        if(cid.equals(&sentence_correction_id)) { return underlayer_content::render_hat_sentence_correction() }
        if(cid.equals(&critical_reading_id)) { return underlayer_content::render_hat_critical_reading() }
        if(cid.equals(&tenses_id)) { return underlayer_content::render_hat_grammar_tenses() }
        if(cid.equals(&punctuation_id)) { return underlayer_content::render_hat_grammar_punctuation() }
        if(cid.equals(&statement_assumption_id)) { return underlayer_content::render_hat_statement_assumption() }
        if(cid.equals(&statement_conclusion_id)) { return underlayer_content::render_hat_statement_conclusion() }
        if(cid.equals(&strong_weak_id)) { return underlayer_content::render_hat_strong_weak_arguments() }
        if(cid.equals(&course_of_action_id)) { return underlayer_content::render_hat_course_of_action() }
        if(cid.equals(&grouping_id)) { return underlayer_content::render_hat_grouping_puzzles() }
        if(cid.equals(&network_id)) { return underlayer_content::render_hat_network_routing() }
        if(cid.equals(&sets_venn_id)) { return underlayer_content::render_hat_sets_venn() }
        if(cid.equals(&review_method_id)) { return underlayer_content::render_hat_review_method() }
        if(cid.equals(&energy_id)) { return underlayer_content::render_hat_energy_management() }
        return string()
    }

    // PE course concept ids. Prefixed with `pe-` to stay unique across
    // courses (same convention as the HAT `hat-` prefix).
    public func render_pe_concept(concept_id : *string) : string {
        var cid = concept_id.copy()
        var intro_id = std::string("pe-intro")
        var layout_id = std::string("pe-file-layout")
        var coff_id = std::string("pe-coff-basics")
        var dos_id = std::string("pe-dos-header")
        var sig_id = std::string("pe-signature-coff")
        var opt_id = std::string("pe-optional-header")
        var ddir_id = std::string("pe-data-directories")
        var addr_id = std::string("pe-addresses")
        var rva_id = std::string("pe-rva-conversion")
        var sht_id = std::string("pe-section-table")
        var csec_id = std::string("pe-common-sections")
        var align_id = std::string("pe-alignment")
        var imp_id = std::string("pe-imports")
        var exp_id = std::string("pe-exports")
        var delay_id = std::string("pe-delay-loads")
        var reloc_id = std::string("pe-base-relocations")
        var secflags_id = std::string("pe-security-flags")
        var loadcfg_id = std::string("pe-load-config")
        var rsrc_id = std::string("pe-resources")
        var tls_id = std::string("pe-tls")
        var except_id = std::string("pe-exceptions")
        var loader_id = std::string("pe-loader")
        var mem_id = std::string("pe-memory-layout")
        var exec_id = std::string("pe-execution")

        if(cid.equals(&intro_id)) { return underlayer_content::render_pe_intro() }
        if(cid.equals(&layout_id)) { return underlayer_content::render_pe_file_layout() }
        if(cid.equals(&coff_id)) { return underlayer_content::render_pe_coff_basics() }
        if(cid.equals(&dos_id)) { return underlayer_content::render_pe_dos_header() }
        if(cid.equals(&sig_id)) { return underlayer_content::render_pe_signature_coff() }
        if(cid.equals(&opt_id)) { return underlayer_content::render_pe_optional_header() }
        if(cid.equals(&ddir_id)) { return underlayer_content::render_pe_data_directories() }
        if(cid.equals(&addr_id)) { return underlayer_content::render_pe_addresses() }
        if(cid.equals(&rva_id)) { return underlayer_content::render_pe_rva_conversion() }
        if(cid.equals(&sht_id)) { return underlayer_content::render_pe_section_table() }
        if(cid.equals(&csec_id)) { return underlayer_content::render_pe_common_sections() }
        if(cid.equals(&align_id)) { return underlayer_content::render_pe_alignment() }
        if(cid.equals(&imp_id)) { return underlayer_content::render_pe_imports() }
        if(cid.equals(&exp_id)) { return underlayer_content::render_pe_exports() }
        if(cid.equals(&delay_id)) { return underlayer_content::render_pe_delay_loads() }
        if(cid.equals(&reloc_id)) { return underlayer_content::render_pe_base_relocations() }
        if(cid.equals(&secflags_id)) { return underlayer_content::render_pe_security_flags() }
        if(cid.equals(&loadcfg_id)) { return underlayer_content::render_pe_load_config() }
        if(cid.equals(&rsrc_id)) { return underlayer_content::render_pe_resources() }
        if(cid.equals(&tls_id)) { return underlayer_content::render_pe_tls() }
        if(cid.equals(&except_id)) { return underlayer_content::render_pe_exceptions() }
        if(cid.equals(&loader_id)) { return underlayer_content::render_pe_loader() }
        if(cid.equals(&mem_id)) { return underlayer_content::render_pe_memory_layout() }
        if(cid.equals(&exec_id)) { return underlayer_content::render_pe_execution() }
        return string()
    }

    // DWARF course concept ids. Prefixed with `dwarf-` to stay unique across
    // courses (same convention as the HAT `hat-`, PE `pe-` and Mach-O
    // `macho-` prefixes).
    public func render_dwarf_concept(concept_id : *string) : string {
        var cid = concept_id.copy()
        var intro_id = std::string("dwarf-intro")
        var sections_id = std::string("dwarf-sections")
        var versions_id = std::string("dwarf-versions")
        var lineheader_id = std::string("dwarf-line-header")
        var filetables_id = std::string("dwarf-file-tables")
        var stdopcodes_id = std::string("dwarf-standard-opcodes")
        var specopcodes_id = std::string("dwarf-special-opcodes")
        var addrtoline_id = std::string("dwarf-address-to-line")
        var dies_id = std::string("dwarf-dies")
        var types_id = std::string("dwarf-types")
        var scopes_id = std::string("dwarf-scopes")
        var locations_id = std::string("dwarf-locations")
        var frames_id = std::string("dwarf-frames")
        var split_id = std::string("dwarf-split")
        var lookup_id = std::string("dwarf-lookup")
        var loclists_id = std::string("dwarf-loclists")
        var rnglists_id = std::string("dwarf-rnglists")
        var portability_id = std::string("dwarf-portability")
        var packages_id = std::string("dwarf-packages")
        var v4_id = std::string("dwarf-v4")
        var typeunits_id = std::string("dwarf-type-units")
        var callsites_id = std::string("dwarf-call-sites")
        var frame_id = std::string("dwarf-frame")

        if(cid.equals(&intro_id)) { return underlayer_content::render_dwarf_intro() }
        if(cid.equals(&sections_id)) { return underlayer_content::render_dwarf_sections() }
        if(cid.equals(&versions_id)) { return underlayer_content::render_dwarf_versions() }
        if(cid.equals(&lineheader_id)) { return underlayer_content::render_dwarf_line_header() }
        if(cid.equals(&filetables_id)) { return underlayer_content::render_dwarf_file_tables() }
        if(cid.equals(&stdopcodes_id)) { return underlayer_content::render_dwarf_standard_opcodes() }
        if(cid.equals(&specopcodes_id)) { return underlayer_content::render_dwarf_special_opcodes() }
        if(cid.equals(&addrtoline_id)) { return underlayer_content::render_dwarf_address_to_line() }
        if(cid.equals(&dies_id)) { return underlayer_content::render_dwarf_dies() }
        if(cid.equals(&types_id)) { return underlayer_content::render_dwarf_types() }
        if(cid.equals(&scopes_id)) { return underlayer_content::render_dwarf_scopes() }
        if(cid.equals(&locations_id)) { return underlayer_content::render_dwarf_locations() }
        if(cid.equals(&frames_id)) { return underlayer_content::render_dwarf_frames() }
        if(cid.equals(&split_id)) { return underlayer_content::render_dwarf_split() }
        if(cid.equals(&lookup_id)) { return underlayer_content::render_dwarf_lookup() }
        if(cid.equals(&loclists_id)) { return underlayer_content::render_dwarf_loclists() }
        if(cid.equals(&rnglists_id)) { return underlayer_content::render_dwarf_rnglists() }
        if(cid.equals(&portability_id)) { return underlayer_content::render_dwarf_portability() }
        if(cid.equals(&packages_id)) { return underlayer_content::render_dwarf_packages() }
        if(cid.equals(&v4_id)) { return underlayer_content::render_dwarf_v4() }
        if(cid.equals(&typeunits_id)) { return underlayer_content::render_dwarf_type_units() }
        if(cid.equals(&callsites_id)) { return underlayer_content::render_dwarf_call_sites() }
        if(cid.equals(&frame_id)) { return underlayer_content::render_dwarf_frame() }
        return string()
    }

    // COFF course concept ids. Prefixed with `coff-` to stay unique across
    // courses (same convention as the HAT `hat-`, PE `pe-`, Mach-O `macho-`
    // and DWARF `dwarf-` prefixes).
    public func render_coff_concept(concept_id : *string) : string {
        var cid = concept_id.copy()
        var intro_id = std::string("coff-intro")
        var fileheader_id = std::string("coff-file-header")
        var sectiontable_id = std::string("coff-section-table")
        var characteristics_id = std::string("coff-characteristics")
        var strtable_id = std::string("coff-string-table")
        var symtable_id = std::string("coff-symbol-table")
        var relocs_id = std::string("coff-relocations")
        var comdat_id = std::string("coff-comdat")
        var bigobj_id = std::string("coff-bigobj")
        var archives_id = std::string("coff-archives")
        var linenumbers_id = std::string("coff-line-numbers")
        var linking_id = std::string("coff-linking")
        var mapfiles_id = std::string("coff-map-files")
        var comdatlinking_id = std::string("coff-comdat-linking")
        var arm64_id = std::string("coff-arm64")
        var tls_id = std::string("coff-tls")
        var weak_id = std::string("coff-weak-externals")
        var drectve_id = std::string("coff-drectve")

        if(cid.equals(&intro_id)) { return underlayer_content::render_coff_intro() }
        if(cid.equals(&fileheader_id)) { return underlayer_content::render_coff_file_header() }
        if(cid.equals(&sectiontable_id)) { return underlayer_content::render_coff_section_table() }
        if(cid.equals(&characteristics_id)) { return underlayer_content::render_coff_characteristics() }
        if(cid.equals(&strtable_id)) { return underlayer_content::render_coff_string_table() }
        if(cid.equals(&symtable_id)) { return underlayer_content::render_coff_symbol_table() }
        if(cid.equals(&relocs_id)) { return underlayer_content::render_coff_relocations() }
        if(cid.equals(&comdat_id)) { return underlayer_content::render_coff_comdat() }
        if(cid.equals(&bigobj_id)) { return underlayer_content::render_coff_bigobj() }
        if(cid.equals(&archives_id)) { return underlayer_content::render_coff_archives() }
        if(cid.equals(&linenumbers_id)) { return underlayer_content::render_coff_line_numbers() }
        if(cid.equals(&linking_id)) { return underlayer_content::render_coff_linking() }
        if(cid.equals(&mapfiles_id)) { return underlayer_content::render_coff_map_files() }
        if(cid.equals(&comdatlinking_id)) { return underlayer_content::render_coff_comdat_linking() }
        if(cid.equals(&arm64_id)) { return underlayer_content::render_coff_arm64() }
        if(cid.equals(&tls_id)) { return underlayer_content::render_coff_tls() }
        if(cid.equals(&weak_id)) { return underlayer_content::render_coff_weak_externals() }
        if(cid.equals(&drectve_id)) { return underlayer_content::render_coff_drectve() }
        return string()
    }

    // Mach-O course concept ids. Prefixed with `macho-` to stay unique across
    // courses (same convention as the HAT `hat-` and PE `pe-` prefixes).
    public func render_macho_concept(concept_id : *string) : string {
        var cid = concept_id.copy()
        var intro_id = std::string("macho-intro")
        var layout_id = std::string("macho-file-layout")
        var magic_id = std::string("macho-magic")
        var header_id = std::string("macho-header")
        var cputypes_id = std::string("macho-cputypes")
        var universal_id = std::string("macho-universal")
        var loadcmds_id = std::string("macho-load-commands")
        var segments_id = std::string("macho-segments")
        var sections_id = std::string("macho-sections")
        var symtab_id = std::string("macho-symtab")
        var dysymtab_id = std::string("macho-dysymtab")
        var relocations_id = std::string("macho-relocations")
        var dylibs_id = std::string("macho-dylibs")
        var dyldinfo_id = std::string("macho-dyld-info")
        var exporttrie_id = std::string("macho-export-trie")
        var chained_id = std::string("macho-chained-fixups")
        var entry_id = std::string("macho-entry")
        var buildver_id = std::string("macho-build-version")
        var codesign_id = std::string("macho-code-signing")
        var debuginfo_id = std::string("macho-debug-info")
        var hardening_id = std::string("macho-hardening")
        var dyld_id = std::string("macho-dyld")
        var memlayout_id = std::string("macho-memory-layout")
        var exec_id = std::string("macho-execution")

        if(cid.equals(&intro_id)) { return underlayer_content::render_macho_intro() }
        if(cid.equals(&layout_id)) { return underlayer_content::render_macho_file_layout() }
        if(cid.equals(&magic_id)) { return underlayer_content::render_macho_magic() }
        if(cid.equals(&header_id)) { return underlayer_content::render_macho_header() }
        if(cid.equals(&cputypes_id)) { return underlayer_content::render_macho_cputypes() }
        if(cid.equals(&universal_id)) { return underlayer_content::render_macho_universal() }
        if(cid.equals(&loadcmds_id)) { return underlayer_content::render_macho_load_commands() }
        if(cid.equals(&segments_id)) { return underlayer_content::render_macho_segments() }
        if(cid.equals(&sections_id)) { return underlayer_content::render_macho_sections() }
        if(cid.equals(&symtab_id)) { return underlayer_content::render_macho_symtab() }
        if(cid.equals(&dysymtab_id)) { return underlayer_content::render_macho_dysymtab() }
        if(cid.equals(&relocations_id)) { return underlayer_content::render_macho_relocations() }
        if(cid.equals(&dylibs_id)) { return underlayer_content::render_macho_dylibs() }
        if(cid.equals(&dyldinfo_id)) { return underlayer_content::render_macho_dyld_info() }
        if(cid.equals(&exporttrie_id)) { return underlayer_content::render_macho_export_trie() }
        if(cid.equals(&chained_id)) { return underlayer_content::render_macho_chained_fixups() }
        if(cid.equals(&entry_id)) { return underlayer_content::render_macho_entry() }
        if(cid.equals(&buildver_id)) { return underlayer_content::render_macho_build_version() }
        if(cid.equals(&codesign_id)) { return underlayer_content::render_macho_code_signing() }
        if(cid.equals(&debuginfo_id)) { return underlayer_content::render_macho_debug_info() }
        if(cid.equals(&hardening_id)) { return underlayer_content::render_macho_hardening() }
        if(cid.equals(&dyld_id)) { return underlayer_content::render_macho_dyld() }
        if(cid.equals(&memlayout_id)) { return underlayer_content::render_macho_memory_layout() }
        if(cid.equals(&exec_id)) { return underlayer_content::render_macho_execution() }
        return string()
    }

    // WebAssembly course concept ids. Prefixed with `wasm-` to stay unique
    // across courses (same convention as the `dwarf-`, `coff-` and `macho-`
    // prefixes). Returns an empty string for ids it does not own, so
    // render_concept can fall through.
    public func render_wasm_concept(concept_id : *string) : string {
        var cid = concept_id.copy()
        var intro_id = std::string("wasm-intro")
        var header_id = std::string("wasm-header")
        var sections_id = std::string("wasm-sections")
        var leb128_id = std::string("wasm-leb128")
        var types_id = std::string("wasm-types")
        var imports_id = std::string("wasm-imports")
        var tables_id = std::string("wasm-tables-memories")
        var globals_id = std::string("wasm-globals")
        var code_id = std::string("wasm-code")
        var instructions_id = std::string("wasm-instructions")
        var elements_id = std::string("wasm-elements")
        var data_id = std::string("wasm-data")
        var objects_id = std::string("wasm-objects")

        if(cid.equals(&intro_id)) { return underlayer_content::render_wasm_intro() }
        if(cid.equals(&header_id)) { return underlayer_content::render_wasm_header() }
        if(cid.equals(&sections_id)) { return underlayer_content::render_wasm_sections() }
        if(cid.equals(&leb128_id)) { return underlayer_content::render_wasm_leb128() }
        if(cid.equals(&types_id)) { return underlayer_content::render_wasm_types() }
        if(cid.equals(&imports_id)) { return underlayer_content::render_wasm_imports() }
        if(cid.equals(&tables_id)) { return underlayer_content::render_wasm_tables_memories() }
        if(cid.equals(&globals_id)) { return underlayer_content::render_wasm_globals() }
        if(cid.equals(&code_id)) { return underlayer_content::render_wasm_code() }
        if(cid.equals(&instructions_id)) { return underlayer_content::render_wasm_instructions() }
        if(cid.equals(&elements_id)) { return underlayer_content::render_wasm_elements() }
        if(cid.equals(&data_id)) { return underlayer_content::render_wasm_data() }
        if(cid.equals(&objects_id)) { return underlayer_content::render_wasm_objects() }
        return string()
    }

    // JVM class file course concept ids. Same `jvm-` prefix convention as the
    // `wasm-`, `dwarf-`, `coff-` and `macho-` prefixes. Returns an empty
    // string for ids it does not own so render_concept can fall through.
    // Object Files course concept ids. The `obj-` prefix, same convention as
    // the `jvm-`, `wasm-`, `dwarf-`, `coff-` and `macho-` prefixes. Returns an
    // empty string for ids it does not own so render_concept can fall through.
    public func render_obj_concept(concept_id : *string) : string {
        var cid = concept_id.copy()
        var intro_id = std::string("obj-intro")
        var hole_id = std::string("obj-the-hole")
        var triangulate_id = std::string("obj-triangulate")
        var no_segments_id = std::string("obj-no-segments")
        var sections_id = std::string("obj-sections")
        var symbols_id = std::string("obj-symbols")

        if(cid.equals(&intro_id)) { return underlayer_content::render_obj_intro() }
        if(cid.equals(&hole_id)) { return underlayer_content::render_obj_the_hole() }
        if(cid.equals(&triangulate_id)) { return underlayer_content::render_obj_triangulate() }
        if(cid.equals(&no_segments_id)) { return underlayer_content::render_obj_no_segments() }
        if(cid.equals(&sections_id)) { return underlayer_content::render_obj_sections() }
        if(cid.equals(&symbols_id)) { return underlayer_content::render_obj_symbols() }
        return string()
    }

    public func render_jvm_concept(concept_id : *string) : string {
        var cid = concept_id.copy()
        var intro_id = std::string("jvm-intro")
        var header_id = std::string("jvm-header")
        var pool_id = std::string("jvm-constant-pool")
        var strings_id = std::string("jvm-strings")
        var members_id = std::string("jvm-members")
        var code_id = std::string("jvm-code")
        var branches_id = std::string("jvm-branches")
        var stackmaps_id = std::string("jvm-stackmaps")
        var attributes_id = std::string("jvm-attributes")
        var inner_classes_id = std::string("jvm-inner-classes")
        var signatures_id = std::string("jvm-signatures")
        var annotations_id = std::string("jvm-annotations")
        var records_id = std::string("jvm-records")
        var sealed_id = std::string("jvm-sealed")
        var enums_id = std::string("jvm-enums")
        var indy_id = std::string("jvm-invokedynamic")
        var modules_id = std::string("jvm-modules")
        var versions_id = std::string("jvm-versions")

        if(cid.equals(&intro_id)) { return underlayer_content::render_jvm_intro() }
        if(cid.equals(&header_id)) { return underlayer_content::render_jvm_header() }
        if(cid.equals(&pool_id)) { return underlayer_content::render_jvm_constant_pool() }
        if(cid.equals(&strings_id)) { return underlayer_content::render_jvm_strings() }
        if(cid.equals(&members_id)) { return underlayer_content::render_jvm_members() }
        if(cid.equals(&code_id)) { return underlayer_content::render_jvm_code() }
        if(cid.equals(&branches_id)) { return underlayer_content::render_jvm_branches() }
        if(cid.equals(&stackmaps_id)) { return underlayer_content::render_jvm_stackmaps() }
        if(cid.equals(&attributes_id)) { return underlayer_content::render_jvm_attributes() }
        if(cid.equals(&inner_classes_id)) { return underlayer_content::render_jvm_inner_classes() }
        if(cid.equals(&signatures_id)) { return underlayer_content::render_jvm_signatures() }
        if(cid.equals(&annotations_id)) { return underlayer_content::render_jvm_annotations() }
        if(cid.equals(&records_id)) { return underlayer_content::render_jvm_records() }
        if(cid.equals(&sealed_id)) { return underlayer_content::render_jvm_sealed() }
        if(cid.equals(&enums_id)) { return underlayer_content::render_jvm_enums() }
        if(cid.equals(&indy_id)) { return underlayer_content::render_jvm_invokedynamic() }
        if(cid.equals(&modules_id)) { return underlayer_content::render_jvm_modules() }
        if(cid.equals(&versions_id)) { return underlayer_content::render_jvm_versions() }
        return string()
    }

    public func render_concept(concept_id : *string) : string {
        var cid = concept_id.copy()
        // HAT concepts are resolved first; render_hat_concept returns an empty
        // string for ids it does not own, so unknown ids fall through to the
        // PE table below.
        var hat_html = render_hat_concept(concept_id)
        if(hat_html.size() > 0) { return hat_html }
        // PE concepts next; same fall-through contract as HAT.
        var pe_html = render_pe_concept(concept_id)
        if(pe_html.size() > 0) { return pe_html }
        // Mach-O concepts next; same fall-through contract.
        var macho_html = render_macho_concept(concept_id)
        if(macho_html.size() > 0) { return macho_html }
        // DWARF concepts next; same fall-through contract.
        var dwarf_html = render_dwarf_concept(concept_id)
        if(dwarf_html.size() > 0) { return dwarf_html }
        // COFF concepts next; same fall-through contract.
        var coff_html = render_coff_concept(concept_id)
        if(coff_html.size() > 0) { return coff_html }
        // WebAssembly concepts next; same fall-through contract.
        var wasm_html = render_wasm_concept(concept_id)
        if(wasm_html.size() > 0) { return wasm_html }
        // JVM class file concepts next; same fall-through contract.
        var obj_html = render_obj_concept(concept_id)
        if(obj_html.size() > 0) { return obj_html }
        var jvm_html = render_jvm_concept(concept_id)
        if(jvm_html.size() > 0) { return jvm_html }
        var bytes_id = std::string("bytes")
        var binrep_id = std::string("binary-representation")
        var filelayout_id = std::string("file-layout")
        var elfident_id = std::string("elf-identification")
        var elfheader_id = std::string("elf-header-fields")
        var entrypoint_id = std::string("entry-point")
        var progheader_id = std::string("program-header-table")
        var segtype_id = std::string("segment-types")
        var memmap_id = std::string("memory-mapping")
        var sectheader_id = std::string("section-header-table")
        var commonsec_id = std::string("common-sections")
        var secvsseg_id = std::string("section-vs-segment")
        var symtable_id = std::string("symbol-table")
        var binding_id = std::string("binding")
        var visibility_id = std::string("visibility")
        var relocentries_id = std::string("relocation-entries")
        var rectypes_id = std::string("relocation-types")
        var dynreloc_id = std::string("dynamic-relocations")
        var dynsect_id = std::string("dynamic-section")
        var sharedlib_id = std::string("shared-libraries")
        var ldso_id = std::string("ld-so")
        var loader_id = std::string("loader")
        var memlayout_id = std::string("memory-layout")
        var exec_id = std::string("execution")

        if(cid.equals(&bytes_id)) { return underlayer_content::render_bytes() }
        if(cid.equals(&binrep_id)) { return underlayer_content::render_binary_representation() }
        if(cid.equals(&filelayout_id)) { return underlayer_content::render_file_layout() }
        if(cid.equals(&elfident_id)) { return underlayer_content::render_elf_identification() }
        if(cid.equals(&elfheader_id)) { return underlayer_content::render_elf_header_fields() }
        if(cid.equals(&entrypoint_id)) { return underlayer_content::render_entry_point() }
        if(cid.equals(&progheader_id)) { return underlayer_content::render_program_header_table() }
        if(cid.equals(&segtype_id)) { return underlayer_content::render_segment_types() }
        if(cid.equals(&memmap_id)) { return underlayer_content::render_memory_mapping() }
        if(cid.equals(&sectheader_id)) { return underlayer_content::render_section_header_table() }
        if(cid.equals(&commonsec_id)) { return underlayer_content::render_common_sections() }
        if(cid.equals(&secvsseg_id)) { return underlayer_content::render_section_vs_segment() }
        if(cid.equals(&symtable_id)) { return underlayer_content::render_symbol_table() }
        if(cid.equals(&binding_id)) { return underlayer_content::render_binding() }
        if(cid.equals(&visibility_id)) { return underlayer_content::render_visibility() }
        if(cid.equals(&relocentries_id)) { return underlayer_content::render_relocation_entries() }
        if(cid.equals(&rectypes_id)) { return underlayer_content::render_relocation_types() }
        if(cid.equals(&dynreloc_id)) { return underlayer_content::render_dynamic_relocations() }
        if(cid.equals(&dynsect_id)) { return underlayer_content::render_dynamic_section() }
        if(cid.equals(&sharedlib_id)) { return underlayer_content::render_shared_libraries() }
        if(cid.equals(&ldso_id)) { return underlayer_content::render_ld_so() }
        if(cid.equals(&loader_id)) { return underlayer_content::render_loader() }
        if(cid.equals(&memlayout_id)) { return underlayer_content::render_memory_layout() }
        if(cid.equals(&exec_id)) { return underlayer_content::render_execution() }
        return string()
    }

}
