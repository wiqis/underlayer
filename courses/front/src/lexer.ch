// Compiler Front End — concept 1: the lexer.
// All markup is authored through #html / #css / #js macros, never strings.
public namespace front_pages {

using std::string
using std::string_view

public func render_fe_lexer() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("A Lexer You Can Check — Underlayer")
    page.appendTitle(&title)

    underlayer_content::render_lesson_nav(&mut page)
    underlayer_content::render_lesson_css(&mut page)
    underlayer_content::render_lesson_js(&mut page)

    #html {
        <div class="lesson front-lesson">
            <a href="/courses/front" class="back-link">Back to course</a>
            <h1>A Lexer You Can Check</h1>
            <div class="lesson-meta">22 min &middot; Module 1: The Front End &middot; Foundations</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>A parser never sees your source text. It sees a stream of small, named things, and the component that turns characters into that stream is the <strong>lexer</strong>. Get it wrong and the parser is asked to make sense of a token that should never have existed.</p>
                <p>This course uses a real language, not a made-up one: the integer arithmetic expressions of Python, restricted to names, numbers, the four arithmetic operators and parentheses. Because the language is real, a real interpreter can check every token our lexer emits. The specimen for this lesson is a single line of text in <code>courses/front/assets/samples/specimen.src</code>, and the authoritative token stream is in <code>specimen.tokens.json</code>.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>For now, think of a lexer as a finger moving across the text. At each position it asks one question: what kind of thing starts here? Whitespace is skipped. A digit starts a <code>NUMBER</code>. A letter or underscore starts a <code>NAME</code>. One of the five operator characters starts an <code>OP</code>. Anything else is refused with the character and its offset, rather than guessed at.</p>
                <p>That model is useful because it tells you what state the lexer needs: an index into the text, and nothing else. But it is incomplete: it says nothing about how many characters a token consumes. The <code>while</code> loops that follow the first digit or letter are the part the model leaves out.</p>
                <div class="formula">
lex(src):
    i = 0
    while i &lt; length(src):
        if whitespace: i = i + 1; continue
        if digit:      consume digits            -&gt; NUMBER
        if letter/_:   consume letters/digits/_  -&gt; NAME
        if + - * / ( ): consume one character     -&gt; OP
        else:          refuse with offset i
                </div>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>The specimen is <code>a + 2 * (b - 3) / 4</code>, followed by one newline. CPython 3.12.2's <code>tokenize.generate_tokens</code> reports <strong>11</strong> tokens when the newline and end markers are filtered out, in this exact order:</p>
                <div class="hex-dump">
<pre>NAME a | OP + | NUMBER 2 | OP * | OP ( | NAME b | OP - | NUMBER 3 | OP ) | OP / | NUMBER 4</pre>
                </div>
                <p>Two details matter in practice. First, the lexer emits <code>NUMBER 2</code>, not the integer <code>2</code>: the text is the evidence, and conversion to a value is a later decision. Second, the space characters vanish entirely. A lexer that kept them would force every grammar rule to say "optional spaces", which is how grammars become unreadable.</p>
                <p>Toolchain and date: CPython <strong>3.12.2</strong> (tags/v3.12.2:6abddd9, Feb 6 2024, 21:26:36) [MSC v.1937 64 bit (AMD64)], verified <strong>2026-11-28</strong>. The full claim ledger is in <code>courses/front/assets/samples/SOURCES.md</code>.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p><code>runner/frontier.py::lex</code> is the reference implementation. It is deliberately small enough to read in one sitting, and it produces <code>[kind, text]</code> pairs in the order above. The independent reader is CPython's own <code>tokenize</code> module, which shares no code with it. Both readers agree on all <strong>11</strong> tokens of the specimen; that agreement is a check, not an assumption.</p>
                <p>The lexer is bounded: source longer than 4096 characters is refused, and an unexpected character reports its zero-based offset. A learner who types <code>a @ 2</code> gets a message about <code>@</code> at offset 2, not a generic "syntax error".</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <p>Open the <a href="/courses/front/lessons/fe-ast">AST lesson</a> and type a source expression into the runner. The token table you see there is produced by this lexer's algorithm; the reference column is produced by an independent parser in the same page.</p>
                <div class="quiz" id="quiz-fe-lexer">
                    <p>What does the lexer emit for a space between two tokens?</p>
                    <button class="quiz-option" data-correct="true" data-explain="Whitespace is skipped before any token is produced, so grammar rules never have to mention spaces." data-source-ref="courses/front/src/lexer.ch:31" onclick="checkQuiz('quiz-fe-lexer', this)">nothing &mdash; a <code>NUMBER</code> and an <code>OP</code> are adjacent</button>
                    <button class="quiz-option" data-correct="false" data-explain="The token stream contains no whitespace kind in this language." onclick="checkQuiz('quiz-fe-lexer', this)">a <code>SPACE</code> token</button>
                    <button class="quiz-option" data-correct="false" data-explain="Skipping does not join two numbers into one; the digit loop stops at the space." onclick="checkQuiz('quiz-fe-lexer', this)">one merged <code>NUMBER</code></button>
                    <div class="quiz-feedback" aria-live="polite"></div>
                </div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Retrieve</h2>
                <p>Without looking back: how many tokens does the specimen produce, and what are the first three? The answer is 11, and the first three are <code>NAME a</code>, <code>OP +</code>, <code>NUMBER 2</code>. If you missed it, that is fine — the act of recalling is the point.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Apply</h2>
                <p>Take <code>x * (7 - 2)</code>. Write down the token stream before reading the answer: <code>NAME x</code>, <code>OP *</code>, <code>OP (</code>, <code>NUMBER 7</code>, <code>OP -</code>, <code>NUMBER 2</code>, <code>OP )</code> — seven tokens. Only then run the reference lexer and compare.</p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>The token stream is the input to the parser. Next we write a <strong>recursive-descent parser</strong> that consumes these 11 tokens and builds a tree; the tree itself is the subject of the last concept. Nothing here depends on IR, code generation or object files — those are separate links in the chain, taught elsewhere.</p>
            </div>
        </div>
    }

    return page.toString()
}

}
