// Renders the 4 concept templates to courses/elf/output/ for verification.
// Library symbols (std, fs) resolve from app-level imports in chemical.mod.

public func main() : int {
    fs::mkdir("courses/elf/output")
    printf("Rendering concept templates...\n")

    var html = underlayer_content::template_standard()
    fs::write_text_file("courses/elf/output/template-standard.html", html.data() as *u8, html.size())
    printf("  -> template-standard.html\n")

    html = underlayer_content::template_exercise_focus()
    fs::write_text_file("courses/elf/output/template-exercise-focus.html", html.data() as *u8, html.size())
    printf("  -> template-exercise-focus.html\n")

    html = underlayer_content::template_visualization()
    fs::write_text_file("courses/elf/output/template-visualization.html", html.data() as *u8, html.size())
    printf("  -> template-visualization.html\n")

    html = underlayer_content::template_mixed()
    fs::write_text_file("courses/elf/output/template-mixed.html", html.data() as *u8, html.size())
    printf("  -> template-mixed.html\n")

    printf("4 templates rendered.\n")
    return 0
}
