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
        var bss_common_id = std::string("obj-bss-common")
        var strings_id = std::string("obj-strings")
        var relocations_id = std::string("obj-relocations")
        var addends_id = std::string("obj-addends")
        var reloc_tables_id = std::string("obj-reloc-tables")
        var pic_id = std::string("obj-pic")
        var comdat_group_id = std::string("obj-comdat-group")
        var archives_id = std::string("obj-archives")
        var weak_undef_id = std::string("obj-weak-undef")
        var emit_id = std::string("obj-emit")
        var arch_table_id = std::string("obj-arch-table")
        var verify_id = std::string("obj-verify")

        if(cid.equals(&intro_id)) { return underlayer_content::render_obj_intro() }
        if(cid.equals(&hole_id)) { return underlayer_content::render_obj_the_hole() }
        if(cid.equals(&triangulate_id)) { return underlayer_content::render_obj_triangulate() }
        if(cid.equals(&no_segments_id)) { return underlayer_content::render_obj_no_segments() }
        if(cid.equals(&sections_id)) { return underlayer_content::render_obj_sections() }
        if(cid.equals(&symbols_id)) { return underlayer_content::render_obj_symbols() }
        if(cid.equals(&bss_common_id)) { return underlayer_content::render_obj_bss_common() }
        if(cid.equals(&strings_id)) { return underlayer_content::render_obj_strings() }
        if(cid.equals(&relocations_id)) { return underlayer_content::render_obj_relocations() }
        if(cid.equals(&addends_id)) { return underlayer_content::render_obj_addends() }
        if(cid.equals(&reloc_tables_id)) { return underlayer_content::render_obj_reloc_tables() }
        if(cid.equals(&pic_id)) { return underlayer_content::render_obj_pic() }
        if(cid.equals(&comdat_group_id)) { return underlayer_content::render_obj_comdat_group() }
        if(cid.equals(&archives_id)) { return underlayer_content::render_obj_archives() }
        if(cid.equals(&weak_undef_id)) { return underlayer_content::render_obj_weak_undef() }
        if(cid.equals(&emit_id)) { return underlayer_content::render_obj_emit() }
        if(cid.equals(&arch_table_id)) { return underlayer_content::render_obj_arch_table() }
        if(cid.equals(&verify_id)) { return underlayer_content::render_obj_verify() }
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

    // Symbol Resolution and Symbol Tables. Owns the 12 `sym-*` ids; returns an
    // empty string for anything else so the fall-through chain keeps working.
    public func render_sym_concept(concept_id : *string) : string {
        var cid = concept_id.copy()
        var intro_id = std::string("sym-intro")
        var binding_id = std::string("sym-binding")
        var visibility_id = std::string("sym-visibility")
        var algorithm_id = std::string("sym-algorithm")
        var order_id = std::string("sym-order")
        var duplicate_id = std::string("sym-duplicate")
        var hash_id = std::string("sym-hash")
        var plt_id = std::string("sym-plt")
        var binding_time_id = std::string("sym-binding-time")
        var copy_reloc_id = std::string("sym-copy-reloc")
        var version_id = std::string("sym-version")
        var linker_defined_id = std::string("sym-linker-defined")

        if(cid.equals(&intro_id)) { return underlayer_content::render_sym_intro() }
        if(cid.equals(&binding_id)) { return underlayer_content::render_sym_binding() }
        if(cid.equals(&visibility_id)) { return underlayer_content::render_sym_visibility() }
        if(cid.equals(&algorithm_id)) { return underlayer_content::render_sym_algorithm() }
        if(cid.equals(&order_id)) { return underlayer_content::render_sym_order() }
        if(cid.equals(&duplicate_id)) { return underlayer_content::render_sym_duplicate() }
        if(cid.equals(&hash_id)) { return underlayer_content::render_sym_hash() }
        if(cid.equals(&plt_id)) { return underlayer_content::render_sym_plt() }
        if(cid.equals(&binding_time_id)) { return underlayer_content::render_sym_binding_time() }
        if(cid.equals(&copy_reloc_id)) { return underlayer_content::render_sym_copy_reloc() }
        if(cid.equals(&version_id)) { return underlayer_content::render_sym_version() }
        if(cid.equals(&linker_defined_id)) { return underlayer_content::render_sym_linker_defined() }
        return string()
    }

    // Relocations, PIC and PIE. Owns the 9 ids below; returns an empty string
    // for anything else so the fall-through chain keeps working. Only the
    // vocabulary module is prefixed `reloc-`, because `pie-`, `pic-` and
    // `tls-` are the other concepts' prefixes.
    public func render_reloc_concept(concept_id : *string) : string {
        var cid = concept_id.copy()
        var arch_id = std::string("reloc-arch-contrast")
        var why_id = std::string("reloc-why-so-many")
        var limits_id = std::string("reloc-encoding-limits")
        var pie_flags_id = std::string("pie-flags")
        var pie_rand_id = std::string("pie-randomize")
        var pie_cost_id = std::string("pie-cost")
        var pic_violation_id = std::string("pic-violation")
        var tls_id = std::string("tls-model")
        var apply_id = std::string("reloc-apply")

        if(cid.equals(&arch_id)) { return underlayer_content::render_reloc_arch_contrast() }
        if(cid.equals(&why_id)) { return underlayer_content::render_reloc_why_so_many() }
        if(cid.equals(&limits_id)) { return underlayer_content::render_reloc_encoding_limits() }
        if(cid.equals(&pie_flags_id)) { return underlayer_content::render_pie_flags() }
        if(cid.equals(&pie_rand_id)) { return underlayer_content::render_pie_randomize() }
        if(cid.equals(&pie_cost_id)) { return underlayer_content::render_pie_cost() }
        if(cid.equals(&pic_violation_id)) { return underlayer_content::render_pic_violation() }
        if(cid.equals(&tls_id)) { return underlayer_content::render_tls_model() }
        if(cid.equals(&apply_id)) { return underlayer_content::render_reloc_apply() }
        return string()
    }

    // Static Linking and Linker Scripts. Owns the 10 ids below; returns an empty
    // string for anything else so the fall-through chain keeps working. Only
    // the script module is prefixed `link-`, because `pie-`, `pic-` and `tls-`
    // are the other concepts' prefixes.
    public func render_link_concept(concept_id : *string) : string {
        var cid = concept_id.copy()
        var default_script_id = std::string("link-default-script")
        var language_id = std::string("link-script-language")
        var order_id = std::string("link-order")
        var counter_id = std::string("link-location-counter")
        var memory_id = std::string("link-memory-regions")
        var phdrs_id = std::string("link-phdrs")
        var keep_gc_id = std::string("link-keep-gc")
        var orphans_id = std::string("link-orphans")
        var static_id = std::string("link-static-real")
        var write_id = std::string("link-write-script")

        if(cid.equals(&default_script_id)) { return underlayer_content::render_link_default_script() }
        if(cid.equals(&language_id)) { return underlayer_content::render_link_script_language() }
        if(cid.equals(&order_id)) { return underlayer_content::render_link_order() }
        if(cid.equals(&counter_id)) { return underlayer_content::render_link_location_counter() }
        if(cid.equals(&memory_id)) { return underlayer_content::render_link_memory_regions() }
        if(cid.equals(&phdrs_id)) { return underlayer_content::render_link_phdrs() }
        if(cid.equals(&keep_gc_id)) { return underlayer_content::render_link_keep_gc() }
        if(cid.equals(&orphans_id)) { return underlayer_content::render_link_orphans() }
        if(cid.equals(&static_id)) { return underlayer_content::render_link_static_real() }
        if(cid.equals(&write_id)) { return underlayer_content::render_link_write_script() }
        return string()
    }

    // Dynamic Linking and Shared Libraries. Owns the 10 ids below; returns an
    // empty string for anything else so the fall-through chain keeps working.
    // Only the scope module is prefixed `dyn-`, because `pie-`, `pic-` and
    // `tls-` are other concepts' prefixes.
    public func render_dyn_concept(concept_id : *string) : string {
        var cid = concept_id.copy()
        var scope_id = std::string("dyn-scope")
        var interpose_id = std::string("dyn-interpose")
        var order_id = std::string("dyn-order-runtime")
        var build_so_id = std::string("dyn-build-so")
        var export_id = std::string("dyn-export")
        var symbolic_id = std::string("dyn-symbolic")
        var dlopen_id = std::string("dyn-dlopen")
        var bind_time_id = std::string("dyn-bind-time")
        var tls_block_id = std::string("dyn-tls-block")
        var resolve_id = std::string("dyn-resolve")

        if(cid.equals(&scope_id)) { return underlayer_content::render_dyn_scope() }
        if(cid.equals(&interpose_id)) { return underlayer_content::render_dyn_interpose() }
        if(cid.equals(&order_id)) { return underlayer_content::render_dyn_order_runtime() }
        if(cid.equals(&build_so_id)) { return underlayer_content::render_dyn_build_so() }
        if(cid.equals(&export_id)) { return underlayer_content::render_dyn_export() }
        if(cid.equals(&symbolic_id)) { return underlayer_content::render_dyn_symbolic() }
        if(cid.equals(&dlopen_id)) { return underlayer_content::render_dyn_dlopen() }
        if(cid.equals(&bind_time_id)) { return underlayer_content::render_dyn_bind_time() }
        if(cid.equals(&tls_block_id)) { return underlayer_content::render_dyn_tls_block() }
        if(cid.equals(&resolve_id)) { return underlayer_content::render_dyn_resolve() }
        return string()
    }

    // Executable images and OS loading. Same fall-through contract: empty
    // string for anything else. `img-` is a prefix no other course uses.
    public func render_img_concept(concept_id : *string) : string {
        var cid = concept_id.copy()
        var auxv_id = std::string("img-auxv")
        var stack_id = std::string("img-stack")
        var entries_id = std::string("img-entries")
        var vdso_id = std::string("img-vdso")
        var place_id = std::string("img-place")
        var walk_id = std::string("img-walk")

        if(cid.equals(&auxv_id)) { return underlayer_content::render_img_auxv() }
        if(cid.equals(&stack_id)) { return underlayer_content::render_img_stack() }
        if(cid.equals(&entries_id)) { return underlayer_content::render_img_entries() }
        if(cid.equals(&vdso_id)) { return underlayer_content::render_img_vdso() }
        if(cid.equals(&place_id)) { return underlayer_content::render_img_place() }
        if(cid.equals(&walk_id)) { return underlayer_content::render_img_walk() }
        return string()
    }

    // Executable security and hardening. Same fall-through contract: empty
    // string for anything else. `sec-` is a prefix no other course uses.
    public func render_sec_concept(concept_id : *string) : string {
        var cid = concept_id.copy()
        var defaults_id = std::string("sec-defaults")
        var canary_id = std::string("sec-canary")
        var relro_id = std::string("sec-relro")
        var fortify_id = std::string("sec-fortify")
        var wx_id = std::string("sec-wx")
        var cet_id = std::string("sec-cet")
        var posture_id = std::string("sec-posture")

        if(cid.equals(&defaults_id)) { return underlayer_content::render_sec_defaults() }
        if(cid.equals(&canary_id)) { return underlayer_content::render_sec_canary() }
        if(cid.equals(&relro_id)) { return underlayer_content::render_sec_relro() }
        if(cid.equals(&fortify_id)) { return underlayer_content::render_sec_fortify() }
        if(cid.equals(&wx_id)) { return underlayer_content::render_sec_wx() }
        if(cid.equals(&cet_id)) { return underlayer_content::render_sec_cet() }
        if(cid.equals(&posture_id)) { return underlayer_content::render_sec_posture() }
        return string()
    }

    // Instruction set architecture. Same fall-through contract: empty string
    // for anything else. `isa-` is a prefix no other course uses.
    public func render_isa_concept(concept_id : *string) : string {
        var cid = concept_id.copy()
        var modes_id = std::string("isa-modes")
        var opcodes_id = std::string("isa-opcodes")
        var rex_id = std::string("isa-rex")
        var modrm_id = std::string("isa-modrm")
        var sib_id = std::string("isa-sib")
        var length_id = std::string("isa-length")
        var decode_id = std::string("isa-decode")

        if(cid.equals(&modes_id)) { return underlayer_content::render_isa_modes() }
        if(cid.equals(&opcodes_id)) { return underlayer_content::render_isa_opcodes() }
        if(cid.equals(&rex_id)) { return underlayer_content::render_isa_rex() }
        if(cid.equals(&modrm_id)) { return underlayer_content::render_isa_modrm() }
        if(cid.equals(&sib_id)) { return underlayer_content::render_isa_sib() }
        if(cid.equals(&length_id)) { return underlayer_content::render_isa_length() }
        if(cid.equals(&decode_id)) { return underlayer_content::render_isa_decode() }
        return string()
    }

    // CPU execution and microarchitecture. Same fall-through contract:
    // empty string for anything else. `exe-` is a prefix no other course uses.
    public func render_exe_concept(concept_id : *string) : string {
        var cid = concept_id.copy()
        var inst_id = std::string("exe-instrument")
        var lat_id = std::string("exe-latency")
        var deps_id = std::string("exe-deps")
        var front_id = std::string("exe-frontend")
        var spec_id = std::string("exe-speculate")
        var ver_id = std::string("exe-verify")

        if(cid.equals(&inst_id)) { return underlayer_content::render_exe_instrument() }
        if(cid.equals(&lat_id)) { return underlayer_content::render_exe_latency() }
        if(cid.equals(&deps_id)) { return underlayer_content::render_exe_deps() }
        if(cid.equals(&front_id)) { return underlayer_content::render_exe_frontend() }
        if(cid.equals(&spec_id)) { return underlayer_content::render_exe_speculate() }
        if(cid.equals(&ver_id)) { return underlayer_content::render_exe_verify() }
        return string()
    }

    // The memory hierarchy. Same fall-through contract: empty string for
    // anything else. `mem-` is a prefix no other course uses.
    public func render_mem_concept(concept_id : *string) : string {
        var cid = concept_id.copy()
        var inst_id = std::string("mem-instrument")
        var lat_id = std::string("mem-latency")
        var hier_id = std::string("mem-hierarchy")
        var assoc_id = std::string("mem-associativity")
        var transl_id = std::string("mem-translation")
        var writes_id = std::string("mem-writes")
        var sharing_id = std::string("mem-sharing")
        var verify_id = std::string("mem-verify")

        if(cid.equals(&inst_id)) { return underlayer_content::render_mem_instrument() }
        if(cid.equals(&lat_id)) { return underlayer_content::render_mem_latency() }
        if(cid.equals(&hier_id)) { return underlayer_content::render_mem_hierarchy() }
        if(cid.equals(&assoc_id)) { return underlayer_content::render_mem_associativity() }
        if(cid.equals(&transl_id)) { return underlayer_content::render_mem_translation() }
        if(cid.equals(&writes_id)) { return underlayer_content::render_mem_writes() }
        if(cid.equals(&sharing_id)) { return underlayer_content::render_mem_sharing() }
        if(cid.equals(&verify_id)) { return underlayer_content::render_mem_verify() }
        return string()
    }

    // Exceptions, privilege and mode changes. Same fall-through contract:
    // empty string for anything else. `priv-` is a prefix no other course uses.
    public func render_priv_concept(concept_id : *string) : string {
        var cid = concept_id.copy()
        var table_id = std::string("priv-table")
        var vectors_id = std::string("priv-vectors")
        var doors_id = std::string("priv-doors")
        var convention_id = std::string("priv-convention")
        var canonical_id = std::string("priv-canonical")
        var errorcode_id = std::string("priv-errorcode")
        var three_id = std::string("priv-three")
        var harness_id = std::string("priv-harness")

        if(cid.equals(&table_id)) { return underlayer_content::render_priv_table() }
        if(cid.equals(&vectors_id)) { return underlayer_content::render_priv_vectors() }
        if(cid.equals(&doors_id)) { return underlayer_content::render_priv_doors() }
        if(cid.equals(&convention_id)) { return underlayer_content::render_priv_convention() }
        if(cid.equals(&canonical_id)) { return underlayer_content::render_priv_canonical() }
        if(cid.equals(&errorcode_id)) { return underlayer_content::render_priv_errorcode() }
        if(cid.equals(&three_id)) { return underlayer_content::render_priv_three() }
        if(cid.equals(&harness_id)) { return underlayer_content::render_priv_harness() }
        return string()
    }

    // Multiprocessor architecture. Same fall-through contract: empty string
    // for anything else. `smp-` is a prefix no other course uses.
    public func render_smp_concept(concept_id : *string) : string {
        var cid = concept_id.copy()
        var topology_id = std::string("smp-topology")
        var sharing_id = std::string("smp-sharing")
        var atomic_id = std::string("smp-atomic")
        var ordering_id = std::string("smp-ordering")
        var numa_id = std::string("smp-numa")
        var three_id = std::string("smp-three")
        var harness_id = std::string("smp-harness")

        if(cid.equals(&topology_id)) { return underlayer_content::render_smp_topology() }
        if(cid.equals(&sharing_id)) { return underlayer_content::render_smp_sharing() }
        if(cid.equals(&atomic_id)) { return underlayer_content::render_smp_atomic() }
        if(cid.equals(&ordering_id)) { return underlayer_content::render_smp_ordering() }
        if(cid.equals(&numa_id)) { return underlayer_content::render_smp_numa() }
        if(cid.equals(&three_id)) { return underlayer_content::render_smp_three() }
        if(cid.equals(&harness_id)) { return underlayer_content::render_smp_harness() }
        return string()
    }

    // x86-64 assembly and encoding. Same fall-through contract: empty
    // string for anything else. `x86-` is a prefix no other course uses,
    // and it is deliberately not `isa-` -- the instruction-set course owns
    // that one and the two are different subjects: this one is the set of
    // instructions and the encodings behind the escapes, that one is how to
    // read an encoding one byte at a time.
    public func render_x86asm_concept(concept_id : *string) : string {
        var cid = concept_id.copy()
        var asm_id = std::string("x86-asm")
        var integers_id = std::string("x86-integers")
        var flags_id = std::string("x86-flags")
        var vex_id = std::string("x86-vex")
        var map_id = std::string("x86-map")

        if(cid.equals(&asm_id)) { return underlayer_content::render_x86_asm() }
        if(cid.equals(&integers_id)) { return underlayer_content::render_x86_integers() }
        if(cid.equals(&flags_id)) { return underlayer_content::render_x86_flags() }
        if(cid.equals(&vex_id)) { return underlayer_content::render_x86_vex() }
        if(cid.equals(&map_id)) { return underlayer_content::render_x86_map() }
        return string()
    }

    // AArch64 assembly and encoding.  Same fall-through contract: empty
    // string for anything else.  `a64-` is a prefix no other course uses,
    // and it is deliberately not `x86-`: the five ids below were checked
    // against every other course in this directory and none of them owns
    // `a64-asm`, `a64-encoding`, `a64-immediate`, `a64-cond` or `a64-verify`.
    // That check matters because render_concept() resolves ids GLOBALLY
    // with no course in the key, so a collision is silent -- the first
    // course to claim a name keeps it and every later one that asks for it
    // gets this course's page.
    public func render_a64asm_concept(concept_id : *string) : string {
        var cid = concept_id.copy()
        var asm_id = std::string("a64-asm")
        var encoding_id = std::string("a64-encoding")
        var immediate_id = std::string("a64-immediate")
        var cond_id = std::string("a64-cond")
        var verify_id = std::string("a64-verify")

        if(cid.equals(&asm_id)) { return underlayer_content::render_a64_asm() }
        if(cid.equals(&encoding_id)) { return underlayer_content::render_a64_encoding() }
        if(cid.equals(&immediate_id)) { return underlayer_content::render_a64_immediate() }
        if(cid.equals(&cond_id)) { return underlayer_content::render_a64_cond() }
        if(cid.equals(&verify_id)) { return underlayer_content::render_a64_verify() }
        return string()
    }

    // The AArch64 Procedure Call Standard.  Same fall-through contract: empty
    // string for anything else.  Five ids, and the prefix is `a64-` again
    // because the AArch64 assembly course already owns it and the ids are
    // disjoint from its five.  Two of the names in the section plan for this
    // course -- `a64-verify` for the artifact concept, which a64asm took
    // first, and `a64-abi` for the course -- were checked against every
    // shipped manifest before these five were chosen, and none of them is in
    // use.  The check matters for the same reason it matters everywhere in
    // this file: render_concept() resolves ids GLOBALLY with no course in the
    // key, so a collision is silent and the first course to claim a name
    // keeps it.
    public func render_a64abi_concept(concept_id : *string) : string {
        var cid = concept_id.copy()
        var aapcs_id = std::string("a64-aapcs")
        var registers_id = std::string("a64-registers")
        var frame_id = std::string("a64-frame")
        var save_id = std::string("a64-save")
        var unwind_id = std::string("a64-unwind")

        if(cid.equals(&aapcs_id)) { return underlayer_content::render_a64_aapcs() }
        if(cid.equals(&registers_id)) { return underlayer_content::render_a64_registers() }
        if(cid.equals(&frame_id)) { return underlayer_content::render_a64_frame() }
        if(cid.equals(&save_id)) { return underlayer_content::render_a64_save() }
        if(cid.equals(&unwind_id)) { return underlayer_content::render_a64_unwind() }
        return string()
    }

    // The x86-64 ABI. Same fall-through contract: empty string for anything
    // else.  `x86-calling` and its five siblings continue the `x86-` prefix
    // the assembly course already owns, and they are deliberately NOT
    // `isa-`: the instruction-set course owns how to read an encoding and
    // this one owns the contract two compilers agree on, which is a different
    // subject with a different kind of evidence -- faults and bit patterns
    // rather than decodes.
    public func render_x86abi_concept(concept_id : *string) : string {
        var cid = concept_id.copy()
        var calling_id = std::string("x86-calling")
        var frame_id = std::string("x86-frame")
        var saved_id = std::string("x86-saved")
        var varargs_id = std::string("x86-varargs")
        var unwind_id = std::string("x86-unwind")
        var verify_id = std::string("x86-verify")

        if(cid.equals(&calling_id)) { return underlayer_content::render_x86_calling() }
        if(cid.equals(&frame_id)) { return underlayer_content::render_x86_frame() }
        if(cid.equals(&saved_id)) { return underlayer_content::render_x86_saved() }
        if(cid.equals(&varargs_id)) { return underlayer_content::render_x86_varargs() }
        if(cid.equals(&unwind_id)) { return underlayer_content::render_x86_unwind() }
        if(cid.equals(&verify_id)) { return underlayer_content::render_x86_verify() }
        return string()
    }

    // The x86-64 machine: privilege, memory and time.  Same
    // fall-through contract: empty string for anything else.  `x86-` is
    // already in use by the assembly and ABI courses, so these nine ids
    // continue it rather than introducing a fourth prefix; the subjects are
    // different enough that no id collides.
    public func render_x86sys_concept(concept_id : *string) : string {
        var cid = concept_id.copy()
        var syscall_id = std::string("x86-syscall")
        var exceptions_id = std::string("x86-exceptions")
        var rings_id = std::string("x86-rings")
        var cr_id = std::string("x86-cr")
        var debug_id = std::string("x86-debug")
        var virtual_id = std::string("x86-virtual")
        var paging_id = std::string("x86-paging")
        var pmu_id = std::string("x86-pmu")
        var boundary_id = std::string("x86-boundary")

        if(cid.equals(&syscall_id)) { return underlayer_content::render_x86_syscall() }
        if(cid.equals(&exceptions_id)) { return underlayer_content::render_x86_exceptions() }
        if(cid.equals(&rings_id)) { return underlayer_content::render_x86_rings() }
        if(cid.equals(&cr_id)) { return underlayer_content::render_x86_cr() }
        if(cid.equals(&debug_id)) { return underlayer_content::render_x86_debug() }
        if(cid.equals(&virtual_id)) { return underlayer_content::render_x86_virtual() }
        if(cid.equals(&paging_id)) { return underlayer_content::render_x86_paging() }
        if(cid.equals(&pmu_id)) { return underlayer_content::render_x86_pmu() }
        if(cid.equals(&boundary_id)) { return underlayer_content::render_x86_boundary() }
        return string()
    }

    // The x86-64 data path: the vector registers, the atomic set, and
    // memory ordering.  Same fall-through contract: empty string for
    // anything else.  The six ids are all names of things -- sse, avx,
    // avx512, atomics, order, bytes -- and none of them is a word another
    // x86 course needed, which is not an accident: a concept id is
    // resolved GLOBALLY by render_concept() with no course in the key, so
    // the only ids that survive are the ones nobody thought of first.
    public func render_x86simd_concept(concept_id : *string) : string {
        var cid = concept_id.copy()
        var sse_id = std::string("x86-sse")
        var avx_id = std::string("x86-avx")
        var avx512_id = std::string("x86-avx512")
        var atomics_id = std::string("x86-atomics")
        var order_id = std::string("x86-order")
        var bytes_id = std::string("x86-bytes")

        if(cid.equals(&sse_id)) { return underlayer_content::render_x86_sse() }
        if(cid.equals(&avx_id)) { return underlayer_content::render_x86_avx() }
        if(cid.equals(&avx512_id)) { return underlayer_content::render_x86_avx512() }
        if(cid.equals(&atomics_id)) { return underlayer_content::render_x86_atomics() }
        if(cid.equals(&order_id)) { return underlayer_content::render_x86_order() }
        if(cid.equals(&bytes_id)) { return underlayer_content::render_x86_bytes() }
        return string()
    }

    // SIMD and vector processing. Same fall-through contract: empty string
    // for anything else. `simd-` is a prefix no other course uses.
    public func render_simd_concept(concept_id : *string) : string {
        var cid = concept_id.copy()
        var width_id = std::string("simd-width")
        var compiler_id = std::string("simd-compiler")
        var shapes_id = std::string("simd-shapes")
        var reduce_id = std::string("simd-reduce")
        var boundaries_id = std::string("simd-boundaries")
        var three_id = std::string("simd-three")
        var harness_id = std::string("simd-harness")

        if(cid.equals(&width_id)) { return underlayer_content::render_simd_width() }
        if(cid.equals(&compiler_id)) { return underlayer_content::render_simd_compiler() }
        if(cid.equals(&shapes_id)) { return underlayer_content::render_simd_shapes() }
        if(cid.equals(&reduce_id)) { return underlayer_content::render_simd_reduce() }
        if(cid.equals(&boundaries_id)) { return underlayer_content::render_simd_boundaries() }
        if(cid.equals(&three_id)) { return underlayer_content::render_simd_three() }
        if(cid.equals(&harness_id)) { return underlayer_content::render_simd_harness() }
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
        // Symbol Resolution concepts; same fall-through contract.
        var sym_html = render_sym_concept(concept_id)
        if(sym_html.size() > 0) { return sym_html }
        // Relocations/PIC/PIE concepts; same fall-through contract.
        var reloc_html = render_reloc_concept(concept_id)
        if(reloc_html.size() > 0) { return reloc_html }
        // Static linking / linker script concepts; same fall-through contract.
        var link_html = render_link_concept(concept_id)
        if(link_html.size() > 0) { return link_html }
        // Dynamic linking / shared library concepts; same fall-through contract.
        var dyn_html = render_dyn_concept(concept_id)
        if(dyn_html.size() > 0) { return dyn_html }
        // Executable images / OS loading concepts; same fall-through contract.
        var img_html = render_img_concept(concept_id)
        if(img_html.size() > 0) { return img_html }
        // Security / hardening concepts; same fall-through contract.
        var sec_html = render_sec_concept(concept_id)
        if(sec_html.size() > 0) { return sec_html }
        // Instruction set concepts; same fall-through contract.
        var isa_html = render_isa_concept(concept_id)
        if(isa_html.size() > 0) { return isa_html }
        // CPU execution concepts; same fall-through contract.
        var exe_html = render_exe_concept(concept_id)
        if(exe_html.size() > 0) { return exe_html }
        // Memory hierarchy concepts; same fall-through contract.
        var mem_html = render_mem_concept(concept_id)
        if(mem_html.size() > 0) { return mem_html }
        // Exceptions/privilege/mode-change concepts; same fall-through contract.
        var priv_html = render_priv_concept(concept_id)
        if(priv_html.size() > 0) { return priv_html }
        // Multiprocessor-architecture concepts; same fall-through contract.
        var smp_html = render_smp_concept(concept_id)
        if(smp_html.size() > 0) { return smp_html }
        // SIMD/vector concepts; same fall-through contract.
        var simd_html = render_simd_concept(concept_id)
        if(simd_html.size() > 0) { return simd_html }
        // x86-64 assembly/encoding concepts; same fall-through contract.
        var x86asm_html = render_x86asm_concept(concept_id)
        if(x86asm_html.size() > 0) { return x86asm_html }
        // AArch64 assembly/encoding concepts; same fall-through contract.
        // Placed after the x86asm lookup and before every other course,
        // because the ids are disjoint and the ORDER of these calls is the
        // order in which a name was claimed.  Nothing here can shadow
        // anything, which is the reason the five ids were chosen with a
        // prefix no other course uses.
        var a64asm_html = render_a64asm_concept(concept_id)
        if(a64asm_html.size() > 0) { return a64asm_html }
        // The AArch64 Procedure Call Standard; same fall-through contract.
        // Placed IMMEDIATELY after the a64asm lookup, because these two
        // courses share a prefix and this one is the ABI half of the subject
        // the other one is the encoding half of.  The order of these calls is
        // the order in which a name was claimed, and the five ids below were
        // checked against every other course in this directory first, so
        // nothing here can shadow anything.
        var a64abi_html = render_a64abi_concept(concept_id)
        if(a64abi_html.size() > 0) { return a64abi_html }
        // x86-64 ABI concepts; same fall-through contract.
        var x86abi_html = render_x86abi_concept(concept_id)
        if(x86abi_html.size() > 0) { return x86abi_html }
        // The x86-64 machine's privileged side, its memory and its time.
        // Same fall-through contract.  The last concept is `x86-boundary`
        // and NOT `x86-verify`: the section plan gives the artifact
        // concept the id `x86-verify` in all THREE of the remaining
        // courses, and a concept id is resolved GLOBALLY by
        // render_concept() with no course in the key, so only the first
        // course to take a name can keep it.  x86abi took it, and this one
        // takes the name of the thing it measures.
        var x86sys_html = render_x86sys_concept(concept_id)
        if(x86sys_html.size() > 0) { return x86sys_html }
        // The x86-64 data path: vectors, atomics and ordering.  Same
        // fall-through contract, and the same collision: the section plan
        // gives this course's artifact concept the id `x86-verify` as
        // well, and x86abi took it first.  This one is `x86-bytes`,
        // because what the artifact does is encode thirty instructions
        // and decode them back, and because the previous course's
        // artifact is `x86-verify` for a reason that is about as clear as
        // a concept id gets.
        var x86simd_html = render_x86simd_concept(concept_id)
        if(x86simd_html.size() > 0) { return x86simd_html }
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
