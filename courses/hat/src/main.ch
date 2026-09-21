// HAT Course - Build entry point
// Renders all concept pages to output/ directory.

public func main() : int {
    fs::mkdir("output")
    printf("Rendering HAT course pages...\n")

    // Module 1: Know the Arena
    var html = underlayer_content::render_hat_exam_overview()
    fs::write_text_file("output/hat-exam-overview.html", html.data() as *u8, html.size())
    printf("  -> hat-exam-overview.html\n")

    html = underlayer_content::render_hat_weightage_strategy()
    fs::write_text_file("output/hat-weightage-strategy.html", html.data() as *u8, html.size())
    printf("  -> hat-weightage-strategy.html\n")

    html = underlayer_content::render_hat_study_plan()
    fs::write_text_file("output/hat-study-plan.html", html.data() as *u8, html.size())
    printf("  -> hat-study-plan.html\n")

    html = underlayer_content::render_hat_time_budget()
    fs::write_text_file("output/hat-time-budget.html", html.data() as *u8, html.size())
    printf("  -> hat-time-budget.html\n")

    html = underlayer_content::render_hat_triage_and_guessing()
    fs::write_text_file("output/hat-triage-and-guessing.html", html.data() as *u8, html.size())
    printf("  -> hat-triage-and-guessing.html\n")

    // Module 2: Quantitative Reasoning
    html = underlayer_content::render_hat_arithmetic()
    fs::write_text_file("output/hat-arithmetic.html", html.data() as *u8, html.size())
    printf("  -> hat-arithmetic.html\n")

    html = underlayer_content::render_hat_number_properties()
    fs::write_text_file("output/hat-number-properties.html", html.data() as *u8, html.size())
    printf("  -> hat-number-properties.html\n")

    html = underlayer_content::render_hat_fractions_decimals()
    fs::write_text_file("output/hat-fractions-decimals.html", html.data() as *u8, html.size())
    printf("  -> hat-fractions-decimals.html\n")

    html = underlayer_content::render_hat_percentages()
    fs::write_text_file("output/hat-percentages.html", html.data() as *u8, html.size())
    printf("  -> hat-percentages.html\n")

    html = underlayer_content::render_hat_ratio_proportion()
    fs::write_text_file("output/hat-ratio-proportion.html", html.data() as *u8, html.size())
    printf("  -> hat-ratio-proportion.html\n")

    html = underlayer_content::render_hat_averages()
    fs::write_text_file("output/hat-averages.html", html.data() as *u8, html.size())
    printf("  -> hat-averages.html\n")

    html = underlayer_content::render_hat_rates_speed_distance()
    fs::write_text_file("output/hat-rates-speed-distance.html", html.data() as *u8, html.size())
    printf("  -> hat-rates-speed-distance.html\n")

    html = underlayer_content::render_hat_work_rate()
    fs::write_text_file("output/hat-work-rate.html", html.data() as *u8, html.size())
    printf("  -> hat-work-rate.html\n")

    html = underlayer_content::render_hat_counting_probability()
    fs::write_text_file("output/hat-counting-probability.html", html.data() as *u8, html.size())
    printf("  -> hat-counting-probability.html\n")

    html = underlayer_content::render_hat_algebra()
    fs::write_text_file("output/hat-algebra.html", html.data() as *u8, html.size())
    printf("  -> hat-algebra.html\n")

    html = underlayer_content::render_hat_geometry()
    fs::write_text_file("output/hat-geometry.html", html.data() as *u8, html.size())
    printf("  -> hat-geometry.html\n")

    html = underlayer_content::render_hat_data_probability()
    fs::write_text_file("output/hat-data-probability.html", html.data() as *u8, html.size())
    printf("  -> hat-data-probability.html\n")

    html = underlayer_content::render_hat_quant_drill()
    fs::write_text_file("output/hat-quant-drill.html", html.data() as *u8, html.size())
    printf("  -> hat-quant-drill.html\n")

    // Module 3: Verbal Reasoning
    html = underlayer_content::render_hat_vocabulary()
    fs::write_text_file("output/hat-vocabulary.html", html.data() as *u8, html.size())
    printf("  -> hat-vocabulary.html\n")

    html = underlayer_content::render_hat_synonyms_antonyms()
    fs::write_text_file("output/hat-synonyms-antonyms.html", html.data() as *u8, html.size())
    printf("  -> hat-synonyms-antonyms.html\n")

    html = underlayer_content::render_hat_analogies()
    fs::write_text_file("output/hat-analogies.html", html.data() as *u8, html.size())
    printf("  -> hat-analogies.html\n")

    html = underlayer_content::render_hat_sentence_completion()
    fs::write_text_file("output/hat-sentence-completion.html", html.data() as *u8, html.size())
    printf("  -> hat-sentence-completion.html\n")

    html = underlayer_content::render_hat_paragraph_completion()
    fs::write_text_file("output/hat-paragraph-completion.html", html.data() as *u8, html.size())
    printf("  -> hat-paragraph-completion.html\n")

    html = underlayer_content::render_hat_grammar_errors()
    fs::write_text_file("output/hat-grammar-errors.html", html.data() as *u8, html.size())
    printf("  -> hat-grammar-errors.html\n")

    html = underlayer_content::render_hat_grammar_agreement()
    fs::write_text_file("output/hat-grammar-agreement.html", html.data() as *u8, html.size())
    printf("  -> hat-grammar-agreement.html\n")

    html = underlayer_content::render_hat_prepositions_idioms()
    fs::write_text_file("output/hat-prepositions-idioms.html", html.data() as *u8, html.size())
    printf("  -> hat-prepositions-idioms.html\n")

    html = underlayer_content::render_hat_reading_comprehension()
    fs::write_text_file("output/hat-reading-comprehension.html", html.data() as *u8, html.size())
    printf("  -> hat-reading-comprehension.html\n")

    html = underlayer_content::render_hat_verbal_drill()
    fs::write_text_file("output/hat-verbal-drill.html", html.data() as *u8, html.size())
    printf("  -> hat-verbal-drill.html\n")

    // Module 4: Analytical Reasoning
    html = underlayer_content::render_hat_critical_reasoning()
    fs::write_text_file("output/hat-critical-reasoning.html", html.data() as *u8, html.size())
    printf("  -> hat-critical-reasoning.html\n")

    html = underlayer_content::render_hat_cause_effect()
    fs::write_text_file("output/hat-cause-effect.html", html.data() as *u8, html.size())
    printf("  -> hat-cause-effect.html\n")

    html = underlayer_content::render_hat_logic_deduction()
    fs::write_text_file("output/hat-logic-deduction.html", html.data() as *u8, html.size())
    printf("  -> hat-logic-deduction.html\n")

    html = underlayer_content::render_hat_seating_arrangements()
    fs::write_text_file("output/hat-seating-arrangements.html", html.data() as *u8, html.size())
    printf("  -> hat-seating-arrangements.html\n")

    html = underlayer_content::render_hat_ordering_scheduling()
    fs::write_text_file("output/hat-ordering-scheduling.html", html.data() as *u8, html.size())
    printf("  -> hat-ordering-scheduling.html\n")

    html = underlayer_content::render_hat_syllogisms()
    fs::write_text_file("output/hat-syllogisms.html", html.data() as *u8, html.size())
    printf("  -> hat-syllogisms.html\n")

    html = underlayer_content::render_hat_relations_and_directions()
    fs::write_text_file("output/hat-relations-and-directions.html", html.data() as *u8, html.size())
    printf("  -> hat-relations-and-directions.html\n")

    html = underlayer_content::render_hat_coding_decoding()
    fs::write_text_file("output/hat-coding-decoding.html", html.data() as *u8, html.size())
    printf("  -> hat-coding-decoding.html\n")

    html = underlayer_content::render_hat_data_sufficiency()
    fs::write_text_file("output/hat-data-sufficiency.html", html.data() as *u8, html.size())
    printf("  -> hat-data-sufficiency.html\n")

    html = underlayer_content::render_hat_data_interpretation()
    fs::write_text_file("output/hat-data-interpretation.html", html.data() as *u8, html.size())
    printf("  -> hat-data-interpretation.html\n")

    html = underlayer_content::render_hat_pattern_series()
    fs::write_text_file("output/hat-pattern-series.html", html.data() as *u8, html.size())
    printf("  -> hat-pattern-series.html\n")

    html = underlayer_content::render_hat_analytical_drill()
    fs::write_text_file("output/hat-analytical-drill.html", html.data() as *u8, html.size())
    printf("  -> hat-analytical-drill.html\n")

    // Module 5: The Athlete's Program
    html = underlayer_content::render_hat_mock_protocol()
    fs::write_text_file("output/hat-mock-protocol.html", html.data() as *u8, html.size())
    printf("  -> hat-mock-protocol.html\n")

    html = underlayer_content::render_hat_error_log()
    fs::write_text_file("output/hat-error-log.html", html.data() as *u8, html.size())
    printf("  -> hat-error-log.html\n")

    html = underlayer_content::render_hat_score_targets()
    fs::write_text_file("output/hat-score-targets.html", html.data() as *u8, html.size())
    printf("  -> hat-score-targets.html\n")

    html = underlayer_content::render_hat_exam_day()
    fs::write_text_file("output/hat-exam-day.html", html.data() as *u8, html.size())
    printf("  -> hat-exam-day.html\n")

    // Module 6: Engineering Foundations (optional background)
    html = underlayer_content::render_hat_physics_mechanics()
    fs::write_text_file("output/hat-physics-mechanics.html", html.data() as *u8, html.size())
    printf("  -> hat-physics-mechanics.html\n")

    html = underlayer_content::render_hat_programming_fundamentals()
    fs::write_text_file("output/hat-programming-fundamentals.html", html.data() as *u8, html.size())
    printf("  -> hat-programming-fundamentals.html\n")

    html = underlayer_content::render_hat_digital_logic()
    fs::write_text_file("output/hat-digital-logic.html", html.data() as *u8, html.size())
    printf("  -> hat-digital-logic.html\n")

    // Landing page
    html = underlayer_content::render_hat_landing()
    fs::write_text_file("output/index.html", html.data() as *u8, html.size())
    printf("  -> index.html\n")

    printf("HAT course: 47 concepts + landing page generated in output/\n")
    return 0
}
