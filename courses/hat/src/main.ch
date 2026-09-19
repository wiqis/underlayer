// HAT Course - Build entry point
// Renders all concept pages to output/ directory.

public func main() : int {
    fs::mkdir("output")
    printf("Rendering HAT course pages...\n")

    // Module 1: Understanding the Test
    var html = underlayer_content::render_hat_exam_overview()
    fs::write_text_file("output/hat-exam-overview.html", html.data() as *u8, html.size())
    printf("  -> hat-exam-overview.html\n")

    html = underlayer_content::render_hat_weightage_strategy()
    fs::write_text_file("output/hat-weightage-strategy.html", html.data() as *u8, html.size())
    printf("  -> hat-weightage-strategy.html\n")

    html = underlayer_content::render_hat_study_plan()
    fs::write_text_file("output/hat-study-plan.html", html.data() as *u8, html.size())
    printf("  -> hat-study-plan.html\n")

    // Module 2: Quantitative Reasoning
    html = underlayer_content::render_hat_arithmetic()
    fs::write_text_file("output/hat-arithmetic.html", html.data() as *u8, html.size())
    printf("  -> hat-arithmetic.html\n")

    html = underlayer_content::render_hat_percentages()
    fs::write_text_file("output/hat-percentages.html", html.data() as *u8, html.size())
    printf("  -> hat-percentages.html\n")

    html = underlayer_content::render_hat_ratio_proportion()
    fs::write_text_file("output/hat-ratio-proportion.html", html.data() as *u8, html.size())
    printf("  -> hat-ratio-proportion.html\n")

    html = underlayer_content::render_hat_algebra()
    fs::write_text_file("output/hat-algebra.html", html.data() as *u8, html.size())
    printf("  -> hat-algebra.html\n")

    html = underlayer_content::render_hat_geometry()
    fs::write_text_file("output/hat-geometry.html", html.data() as *u8, html.size())
    printf("  -> hat-geometry.html\n")

    html = underlayer_content::render_hat_data_probability()
    fs::write_text_file("output/hat-data-probability.html", html.data() as *u8, html.size())
    printf("  -> hat-data-probability.html\n")

    // Module 3: Verbal Reasoning
    html = underlayer_content::render_hat_vocabulary()
    fs::write_text_file("output/hat-vocabulary.html", html.data() as *u8, html.size())
    printf("  -> hat-vocabulary.html\n")

    html = underlayer_content::render_hat_analogies()
    fs::write_text_file("output/hat-analogies.html", html.data() as *u8, html.size())
    printf("  -> hat-analogies.html\n")

    html = underlayer_content::render_hat_sentence_completion()
    fs::write_text_file("output/hat-sentence-completion.html", html.data() as *u8, html.size())
    printf("  -> hat-sentence-completion.html\n")

    html = underlayer_content::render_hat_grammar_errors()
    fs::write_text_file("output/hat-grammar-errors.html", html.data() as *u8, html.size())
    printf("  -> hat-grammar-errors.html\n")

    html = underlayer_content::render_hat_reading_comprehension()
    fs::write_text_file("output/hat-reading-comprehension.html", html.data() as *u8, html.size())
    printf("  -> hat-reading-comprehension.html\n")

    // Module 4: Analytical Reasoning
    html = underlayer_content::render_hat_critical_reasoning()
    fs::write_text_file("output/hat-critical-reasoning.html", html.data() as *u8, html.size())
    printf("  -> hat-critical-reasoning.html\n")

    html = underlayer_content::render_hat_logic_deduction()
    fs::write_text_file("output/hat-logic-deduction.html", html.data() as *u8, html.size())
    printf("  -> hat-logic-deduction.html\n")

    html = underlayer_content::render_hat_data_interpretation()
    fs::write_text_file("output/hat-data-interpretation.html", html.data() as *u8, html.size())
    printf("  -> hat-data-interpretation.html\n")

    html = underlayer_content::render_hat_pattern_series()
    fs::write_text_file("output/hat-pattern-series.html", html.data() as *u8, html.size())
    printf("  -> hat-pattern-series.html\n")

    // Module 5: Subject — Engineering and Computing
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

    printf("HAT course: 21 concepts + landing page generated in output/\n")
    return 0
}
