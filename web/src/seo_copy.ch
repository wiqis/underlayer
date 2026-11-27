// underlayer_web — fixed SEO copy for the non-course pages (I1).
//
// Every string here is ASCII and 140-158 characters long, measured by
// tools/seo_surface_check.py against the served <meta name="description">.
// They are functions, not `@never_destructed string` globals: a zero-initialised
// global string reads back EMPTY at request time (documented in
// wiqis-chemical-language), and appending into one does not survive.
using std::string

public namespace underlayer_web {

    public func seo_desc_home() : string {
        return string("Underlayer teaches hard technical subjects from first principles with verified lessons, active recall and spaced repetition. Start with ELF.")
    }

    public func seo_desc_courses() : string {
        return string("Browse every Underlayer course in one place: formats, architectures, linking, compilers and debugging. Each lesson is verified against real files.")
    }

    public func seo_desc_search() : string {
        return string("Search every Underlayer concept, module and course by keyword. Find verified explanations of ELF, PE, COFF, DWARF, AArch64, RISC-V, linking and compilers.")
    }

    public func seo_desc_path() : string {
        return string("Follow the ordered Underlayer learning path from binary formats through linking, architectures and compilers. Every step builds on the one before it.")
    }

    public func seo_desc_help() : string {
        return string("Get started with Underlayer: create an account, choose a course, work through lessons, use reviews and read your progress. Answers to common questions.")
    }

    public func seo_desc_shortcuts() : string {
        return string("Keyboard shortcuts for Underlayer: open search, move between lessons, rate reviews, toggle the theme and adjust reading controls without leaving the keyboard.")
    }

    public func seo_desc_faq() : string {
        return string("Frequently asked questions about Underlayer: what it teaches, why courses are verified, how spaced repetition works, and what is free and available offline.")
    }

    public func seo_desc_about() : string {
        return string("About Underlayer: a learning platform built on verified technical content, active recall and spaced repetition. Learn how the courses are made.")
    }

    public func seo_desc_terms() : string {
        return string("Underlayer terms of service: account responsibilities, acceptable use, learning content, your own notes, availability, termination and how to contact us.")
    }

    public func seo_desc_privacy() : string {
        return string("Underlayer privacy policy: what learning data is collected, how it is stored, how it is used, your export and deletion choices, and how to contact us.")
    }

}
