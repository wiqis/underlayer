// Compiler Front End — concept 3: the AST and the interactive runner.
public namespace front_pages {

using std::string
using std::string_view

public func render_fe_ast() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Tree, and a Runner You Can Disagree With — Underlayer")
    page.appendTitle(&title)

    underlayer_content::render_lesson_nav(&mut page)
    underlayer_content::render_lesson_css(&mut page)
    underlayer_content::render_lesson_js(&mut page)
    render_runner_js(&mut page)

    #html {
        <div class="lesson front-lesson">
            <a href="/courses/front" class="back-link">Back to course</a>
            <h1>The Tree, and a Runner You Can Disagree With</h1>
            <div class="lesson-meta">24 min &middot; Module 1: The Front End &middot; Core</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>A token stream is a line. A tree is a set of decisions: which operation is the outer one, which operands belong to it, and where the parentheses were. The <strong>abstract syntax tree</strong> is the first representation that a later stage can actually reason about, and it is the point where a front end becomes useful to anything else.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Think of the AST as a nested list of decisions. Each binary operation is a node with a name and two children. A number or a name is a leaf. Parentheses do not appear in the tree at all — they only changed where the nodes attach. That is what "abstract" means here: the tree keeps structure and drops punctuation.</p>
                <div class="formula">
node := &#123;k: 'bin', op: 'Add'|'Sub'|'Mult'|'Div', l: node, r: node&#125;
      | &#123;k: 'un',  op: 'USub', v: node&#125;
      | &#123;k: 'name', v: 'a'&#125;
      | &#123;k: 'num',  v: 2&#125;
                </div>
                <p>The model is incomplete in one useful way: a real language's AST also carries source positions and types. Those are deliberately absent here, and the <a href="/courses/front">course landing</a> says so.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>The specimen's tree has <strong>9</strong> nodes. CPython 3.12.2's <code>ast.parse</code> returns the same shape: <code>Add(a, Div(Mult(2, Sub(b, 3)), 4))</code>. The conversion to our node encoding and the exact JSON are shipped beside the lesson in <code>courses/front/assets/samples/specimen.ast.json</code>. The fixture below is that file, verbatim; the runner compares against it whenever the source matches the specimen.</p>
                <div class="hex-dump">
<pre id="front-fixture" data-source="a + 2 * (b - 3) / 4">&#123;"k": "bin", "op": "Add", "l": &#123;"k": "name", "v": "a"&#125;, "r": &#123;"k": "bin", "op": "Div", "l": &#123;"k": "bin", "op": "Mult", "l": &#123;"k": "num", "v": 2&#125;, "r": &#123;"k": "bin", "op": "Sub", "l": &#123;"k": "name", "v": "b"&#125;, "r": &#123;"k": "num", "v": 3&#125;&#125;&#125;, "r": &#123;"k": "num", "v": 4&#125;&#125;&#125;</pre>
                </div>
                <p>The leap everyone makes once is that <code>-3</code> becomes a single node with value minus three. It does not. The Language Reference says negative numbers are unary operations on a literal, and our fixture would disagree with <code>ast.parse</code> if we folded it. The tree is checked by structure, not by the value you would compute by hand.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Type <code>a + 2 * (b - 3) / 4</code> into the runner below and press Run. You should see 11 token lines, the tree produced by the course's recursive-descent parser, the tree produced by a completely different parser (a Pratt parser, which uses binding powers rather than a call hierarchy), and a verdict. The verdict compares the two trees <strong>by value</strong>: a differently ordered set of object keys is the same tree, and a different operator is not.</p>
                <div class="front-runner">
                    <label for="front-source">Your source expression</label>
                    <input id="front-source" type="text" value="a + 2 * (b - 3) / 4" maxlength="4096" autocomplete="off" spellcheck="false">
                    <button id="front-run" type="button">Tokenise, parse and compare</button>
                    <pre id="front-output" aria-live="polite"></pre>
                    <div class="front-verdict" id="front-verdict" aria-live="polite"></div>
                    <div class="front-error" id="front-error" aria-live="polite"></div>
                </div>
                <p>The runner never evaluates your expression and never executes your input as code. Your text is data. There is no <code>eval</code>, no network request and no file access; input longer than 4096 characters is refused and the parser stops after 100000 steps. A mistake produces a sentence naming the token it could not read, not a stack trace.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <p>Try three inputs in order. First the specimen — both parsers must agree. Then <code>2 * (b - 3) / 4</code> — the tree must show division outside multiplication. Then <code>a +</code> — the runner should say it expected more input at the end of the source, with no crash.</p>
                <div class="quiz" id="quiz-fe-ast">
                    <p>What does the runner do when your tree and the oracle tree differ?</p>
                    <button class="quiz-option" data-correct="true" data-explain="It reports DISAGREE and prints both canonical trees, so you can find the first decision that diverged." onclick="checkQuiz('quiz-fe-ast', this)">prints <code>DISAGREE</code> and both trees</button>
                    <button class="quiz-option" data-correct="false" data-explain="The runner never computes a numeric value; it only compares structure." onclick="checkQuiz('quiz-fe-ast', this)">prints the arithmetic answer</button>
                    <button class="quiz-option" data-correct="false" data-explain="A disagreement is shown as information, not as a failure." onclick="checkQuiz('quiz-fe-ast', this)">hides the result</button>
                    <div class="quiz-feedback" aria-live="polite"></div>
                </div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Retrieve</h2>
                <p>Without looking back: how many nodes does the specimen's tree have, and which operation is its root? Nine nodes, and the root is the addition. The division sits under the addition's right child.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Apply</h2>
                <p>Predict the tree for <code>-a * 2</code>, then type it into the runner. The two parsers should agree on <code>Mult(USub(a), 2)</code>. If they do not, the fixture and the grammar have drifted; the verifier counts that drift rather than letting it hide.</p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>This is where the first link ends: characters to tokens, tokens to a tree, tree checked against a real interpreter. The next link, from a tree to an IR and then to machine code, is the <a href="/courses/compback">Compiler Backend</a> course. Type checking, inference and semantic analysis remain open in the roadmap; this course does not pretend to have taught them.</p>
            </div>
        </div>
    }

    return page.toString()
}

}
