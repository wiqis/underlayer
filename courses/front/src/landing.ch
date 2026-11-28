// Static-mode course landing for `front`.  The server renders its own landing
// from the manifest; this file makes the generated output usable from file://.
public namespace front_pages {

using std::string
using std::string_view

public func render_front_landing() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Compiler Front End — Underlayer")
    page.appendTitle(&title)

    #css {
        body { font-family: var(--font-sans, system-ui, sans-serif); line-height: 1.6; margin: 0; }
        .front-landing { max-width: 68ch; margin: 0 auto; padding: 2rem 1.5rem; }
        .front-landing h1 { font-size: 1.9rem; }
        .front-landing ol { padding-left: 1.4rem; }
        .front-landing li { margin: 0.6rem 0; }
        .front-landing a { color: #1d4ed8; }
        .front-landing .limit { border-left: 3px solid #1d4ed8; padding-left: 0.8rem; }
    }

    #html {
        <main class="front-landing">
            <h1>Compiler Front End</h1>
            <p>The first link in the parsing-to-executable chain: characters to
            tokens, tokens to a tree, and a tree checked against a real
            interpreter. Three concepts, 72 minutes, no backend required.</p>
            <ol>
                <li><a href="fe-lexer.html">A Lexer You Can Check</a> &mdash; 22 min</li>
                <li><a href="fe-recursive-descent.html">Recursive Descent, Written Out</a> &mdash; 26 min</li>
                <li><a href="fe-ast.html">The Tree, and a Runner You Can Disagree With</a> &mdash; 24 min</li>
            </ol>
            <p class="limit">Scope: integers, names, four operators and
            parentheses only. No IR, code generation, object files, linking or
            loading &mdash; those are taught by <a href="../compback">Compiler
            Backend</a>. Verified with CPython 3.12.2 on 2026-11-28; full claim
            ledger in <code>assets/samples/SOURCES.md</code> and
            <code>research.md</code>.</p>
        </main>
    }

    return page.toString()
}

}
