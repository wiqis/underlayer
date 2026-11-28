// Compiler Front End — concept 2: the recursive-descent parser.
public namespace front_pages {

using std::string
using std::string_view

public func render_fe_recursive_descent() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Recursive Descent, Written Out — Underlayer")
    page.appendTitle(&title)

    underlayer_content::render_lesson_nav(&mut page)
    underlayer_content::render_lesson_css(&mut page)
    underlayer_content::render_lesson_js(&mut page)

    #html {
        <div class="lesson front-lesson">
            <a href="/courses/front" class="back-link">Back to course</a>
            <h1>Recursive Descent, Written Out</h1>
            <div class="lesson-meta">26 min &middot; Module 1: The Front End &middot; Core</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>A grammar is a set of rules. A recursive-descent parser is those rules turned into functions: one function per rule, with a call for every reference to another rule. There is no table to generate, no state machine to hide, and no framework to trust. When the parser is wrong, you can point at the function that is wrong.</p>
                <p>The mission asks for a front end you can build yourself. This is the smallest honest version of one: four functions, a token index, and a rule that every function consumes exactly what it claims.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Think of each grammar rule as a worker with one job and one cursor. The worker looks at the current token, decides whether it applies, and hands the cursor to another worker when the rule says so. Recursion happens when a rule refers to itself through parentheses: an expression inside parentheses is another expression, so <code>expr</code> calls <code>expr</code> again.</p>
                <p>That model explains the shape but not the precedence. Without more rules, <code>a + 2 * b</code> would be read left to right as <code>(a + 2) * b</code>. The fix is not a flag; it is four functions arranged in a hierarchy.</p>
                <div class="formula">
expr    := term (('+' | '-') term)*
term    := unary (('*' | '/') unary)*
unary   := '-' unary | primary
primary := NUMBER | NAME | '(' expr ')'
                </div>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>Precedence is read off the Python Language Reference table (§6.17 in the documentation read 2026-11-28): unary <code>+x</code> and <code>-x</code> bind more tightly than <code>*</code> and <code>/</code>, which bind more tightly than <code>+</code> and <code>-</code>. The same paragraph says "Operators in the same box group left to right". Each level of the hierarchy above is one box of that table, and the <code>while</code> loop inside <code>expr</code> and <code>term</code> is the left-to-right grouping.</p>
                <p>The same reference's Literals section states that negative numbers such as <code>-3</code> are "syntactically not literals, but unary or binary arithmetic operations involving the <code>-</code> or <code>+</code> operator". That is why <code>unary()</code> builds a <code>USub</code> node rather than folding a negative number into a literal. A parser that folds it would agree with a real compiler on the value and disagree on the tree.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p><code>runner/frontier.py::parse</code> implements the four functions above. On the specimen's 11 tokens it consumes every token exactly once and returns a tree of <strong>9</strong> nodes. The root is the addition; the right child of that addition is the division; the left child of the division is the multiplication. That shape is not our invention: it is the shape CPython 3.12.2 returns from <code>ast.parse</code>, converted to our node encoding and shipped as <code>specimen.ast.json</code>.</p>
                <p>The trap worth sitting on is <code>2 * (b - 3) / 4</code>. Multiplication and division share a precedence box and group left to right, so the tree is <code>(2 * (b - 3)) / 4</code>, not <code>2 * ((b - 3) / 4)</code>. Both compute the same value here, and only one is the tree a real parser produces. This is why the course checks structure, not arithmetic.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <p>Type <code>2 * (b - 3) / 4</code> into the runner and read the tree. Then type <code>a +</code>: the parser stops and says it expected an operand at the end of the source. It does not crash, and it does not invent a node.</p>
                <div class="quiz" id="quiz-fe-recursive-descent">
                    <p>Why is the multiplication function called before the addition function in the grammar?</p>
                    <button class="quiz-option" data-correct="true" data-explain="A tighter-binding operator must become the child of the looser one, so the function for it is one level deeper in the call chain." onclick="checkQuiz('quiz-fe-recursive-descent', this)">because <code>*</code> and <code>/</code> bind tighter than <code>+</code> and <code>-</code></button>
                    <button class="quiz-option" data-correct="false" data-explain="Function call order has nothing to do with the order tokens appear in the specimen." onclick="checkQuiz('quiz-fe-recursive-descent', this)">because <code>*</code> appears earlier in the specimen</button>
                    <button class="quiz-option" data-correct="false" data-explain="The parser never evaluates an expression; it only builds a tree." onclick="checkQuiz('quiz-fe-recursive-descent', this)">because multiplication is faster to compute</button>
                    <div class="quiz-feedback" aria-live="polite"></div>
                </div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Retrieve</h2>
                <p>Without looking back: which function handles a minus sign at the very start of an expression, and what node does it build? The <code>unary</code> function, and it builds a <code>USub</code> node — an operation, not a negative literal.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Apply</h2>
                <p>Work out the tree for <code>-a * 2</code> by hand. It is <code>Mult(USub(Name(a)), Num(2))</code>: unary minus takes only <code>a</code>, because unary binds tighter than multiplication. Check with <code>ast.parse('-a * 2', mode='eval')</code> rather than with your intuition.</p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>The parser hands a tree to the next concept, which gives the tree a name and a shape: the <a href="/courses/front/lessons/fe-ast">abstract syntax tree</a>. From there the chain continues to a compiler's IR — but that link is taught by <code>compback</code>, not here.</p>
            </div>
        </div>
    }

    return page.toString()
}

}
