// underlayer_web — Help, Guide, FAQ, Shortcuts, and About pages.
using std::string
using std::string_view

public namespace underlayer_web {

    // ---- GET /help — Main help page ----

    public func render_help_page() : string {
        var page = HtmlPage()
        page.defaultUniversalSetup()
        page.defaultPrepare()
        page.injectDefaultComponentsTheme()
        var title = std::string_view("Help & Guide — Underlayer")
        page.appendTitle(&title)

        #html {
            <div class="help-page">
                <div class="help-nav">
                    <a href="/" class="nav-brand">Underlayer</a>
                    <div class="help-nav-links">
                        <a href="/help" class="active">Help</a>
                        <a href="/shortcuts">Shortcuts</a>
                        <a href="/faq">FAQ</a>
                        <a href="/about">About</a>
                    </div>
                </div>

                <div class="help-container">
                    <h1>Help & Guide</h1>
                    <p class="help-subtitle">Everything you need to get the most out of Underlayer.</p>

                    <div class="help-section" id="getting-started">
                        <h2>Getting Started</h2>
                        <div class="help-card">
                            <h3>Creating an Account</h3>
                            <p>Click <strong>Register</strong> in the top navigation to create a free account. You can also browse courses without an account, but progress won't be saved.</p>
                        </div>
                        <div class="help-card">
                            <h3>Choosing a Course</h3>
                            <p>Visit the <a href="/courses/elf">Courses</a> page to see available courses. Each course is structured into modules and concepts, progressing from fundamentals to advanced topics.</p>
                        </div>
                        <div class="help-card">
                            <h3>Starting a Lesson</h3>
                            <p>Click any concept in a course to begin learning. Each lesson includes an explanation, examples, and practice exercises. Work through them at your own pace.</p>
                        </div>
                        <div class="help-card">
                            <h3>Your Dashboard</h3>
                            <p>The <a href="/dashboard">Dashboard</a> gives you a quick overview: due reviews, learning streak, knowledge health, and recommended next steps.</p>
                        </div>
                    </div>

                    <div class="help-section" id="learning-how-to-learn">
                        <h2>Learning How to Learn</h2>
                        <div class="help-card">
                            <h3>Active Recall</h3>
                            <p>Underlayer is built around active recall — the practice of retrieving information from memory. After each lesson, exercises test what you just learned. This is harder than re-reading, but far more effective.</p>
                        </div>
                        <div class="help-card">
                            <h3>Spaced Repetition</h3>
                            <p>The FSRS algorithm schedules reviews just before you forget. This means you review concepts at the optimal time: not too early (wasted effort) and not too late (forgotten). Trust the system — it adapts to you.</p>
                        </div>
                        <div class="help-card">
                            <h3>Struggle Is Normal</h3>
                            <p>If a concept feels hard, that's by design. Difficulty is how learning happens. The platform tracks your struggles and provides targeted review to strengthen weak areas.</p>
                        </div>
                        <div class="help-card">
                            <h3>Daily Reviews</h3>
                            <p>Even 10 minutes of daily review maintains knowledge. The Dashboard shows your due items. Consistency matters more than marathon sessions.</p>
                        </div>
                    </div>

                    <div class="help-section" id="using-reviews">
                        <h2>Using Reviews</h2>
                        <div class="help-card">
                            <h3>Starting a Review</h3>
                            <p>Click <a href="/review">Review</a> in the navigation, or use the "Start Review" button on the Dashboard. You'll see concepts that are due for review.</p>
                        </div>
                        <div class="help-card">
                            <h3>Rating Your Recall</h3>
                            <p>After each review item, rate how well you remembered:</p>
                            <ul>
                                <li><strong>Again</strong> — Forgot completely. Will be shown again soon.</li>
                                <li><strong>Hard</strong> — Recalled with significant difficulty. Interval shortened.</li>
                                <li><strong>Good</strong> — Recalled with some effort. Standard interval.</li>
                                <li><strong>Easy</strong> — Recalled effortlessly. Interval extended significantly.</li>
                            </ul>
                        </div>
                        <div class="help-card">
                            <h3>Review Modes</h3>
                            <p>Underlayer offers multiple review modes: Quick Review, Deep Review, Weakness Focus, and more. Choose based on your available time and learning goals.</p>
                        </div>
                        <div class="help-card">
                            <h3>Session History</h3>
                            <p>Review your past sessions to see how your recall has improved over time. Visit the <a href="/progress">Progress</a> page for detailed analytics.</p>
                        </div>
                    </div>

                    <div class="help-section" id="understanding-progress">
                        <h2>Understanding Progress</h2>
                        <div class="help-card">
                            <h3>Knowledge Health</h3>
                            <p>Your Knowledge Health score reflects how well you've retained concepts. It considers review accuracy, time since last review, and difficulty ratings. A healthy score means your knowledge is stable.</p>
                        </div>
                        <div class="help-card">
                            <h3>Mastery Levels</h3>
                            <p>Each concept progresses through mastery levels: New → Learning → Review → Mastered. The FSRS algorithm determines when you've truly mastered a concept based on your performance.</p>
                        </div>
                        <div class="help-card">
                            <h3>Weakness Detection</h3>
                            <p>The platform automatically identifies concepts you struggle with and groups them by category. Visit the Weakness Dashboard to see targeted repair suggestions.</p>
                        </div>
                        <div class="help-card">
                            <h3>Exporting Data</h3>
                            <p>You can export your progress, review history, and analytics as JSON from the <a href="/settings">Settings</a> page. Your data belongs to you.</p>
                        </div>
                    </div>

                    <div class="help-section" id="keyboard-shortcuts">
                        <h2>Keyboard Shortcuts</h2>
                        <p>Underlayer supports keyboard shortcuts for faster navigation. <a href="/shortcuts">View all shortcuts →</a></p>
                        <div class="shortcut-preview">
                            <div class="shortcut-item">
                                <kbd>Ctrl</kbd> + <kbd>K</kbd>
                                <span>Open search</span>
                            </div>
                            <div class="shortcut-item">
                                <kbd>?</kbd>
                                <span>Show shortcuts</span>
                            </div>
                            <div class="shortcut-item">
                                <kbd>Esc</kbd>
                                <span>Close modal / search</span>
                            </div>
                        </div>
                    </div>

                    <div class="help-section" id="need-more-help">
                        <h2>Need More Help?</h2>
                        <div class="help-card">
                            <p>Check the <a href="/faq">FAQ</a> for common questions, or learn more about Underlayer's mission on the <a href="/about">About</a> page.</p>
                            <p>If you encounter a bug or have a feature request, please open an issue on <a href="https://github.com/anomalyco/opencode/issues">GitHub</a>.</p>
                        </div>
                    </div>
                </div>
            </div>
        }

        #css {
            body { font-family: system-ui, sans-serif; line-height: 1.6; margin: 0; background: hsl(var(--background)); color: hsl(var(--foreground)); }
            .help-nav { background: hsl(var(--card)); border-bottom: 1px solid hsl(var(--border)); padding: 0.75rem 0; position: sticky; top: 0; z-index: 100; }
            .help-nav { max-width: 1200px; margin: 0 auto; padding: 0.75rem 2rem; display: flex; align-items: center; justify-content: space-between; }
            .nav-brand { font-size: 1.25rem; font-weight: 700; color: hsl(var(--foreground)); text-decoration: none; }
            .nav-brand:hover { color: hsl(217 91% 60%); text-decoration: none; }
            .help-nav-links { display: flex; gap: 1.5rem; }
            .help-nav-links a { color: hsl(var(--muted-foreground)); text-decoration: none; font-size: 0.9rem; font-weight: 500; padding: 0.5rem 0.75rem; border-radius: 6px; transition: all 0.15s; }
            .help-nav-links a:hover { color: hsl(var(--foreground)); background: hsl(var(--accent)); text-decoration: none; }
            .help-nav-links a.active { color: hsl(217 91% 60%); background: hsl(217 91% 60% / 10%); }
            .help-container { max-width: 800px; margin: 0 auto; padding: 3rem 2rem; }
            .help-container h1 { font-size: 2rem; margin-bottom: 0.5rem; color: hsl(var(--foreground)); }
            .help-subtitle { color: hsl(var(--muted-foreground)); font-size: 1.1rem; margin-bottom: 3rem; }
            .help-section { margin-bottom: 3rem; }
            .help-section h2 { font-size: 1.4rem; margin-bottom: 1rem; color: hsl(var(--foreground)); padding-bottom: 0.5rem; border-bottom: 1px solid hsl(var(--border)); }
            .help-card { background: hsl(var(--card)); border: 1px solid hsl(var(--border)); border-radius: 10px; padding: 1.25rem; margin-bottom: 1rem; }
            .help-card h3 { font-size: 1.05rem; margin: 0 0 0.5rem 0; color: hsl(var(--foreground)); }
            .help-card p { margin: 0.5rem 0; color: hsl(var(--muted-foreground)); font-size: 0.95rem; }
            .help-card ul { margin: 0.5rem 0; padding-left: 1.5rem; color: hsl(var(--muted-foreground)); font-size: 0.95rem; }
            .help-card li { margin-bottom: 0.35rem; }
            .help-card a { color: hsl(217 91% 60%); text-decoration: none; }
            .help-card a:hover { text-decoration: underline; }
            .shortcut-preview { background: hsl(var(--card)); border: 1px solid hsl(var(--border)); border-radius: 10px; padding: 1rem; display: flex; gap: 2rem; flex-wrap: wrap; }
            .shortcut-item { display: flex; align-items: center; gap: 0.75rem; }
            .shortcut-item kbd { display: inline-block; padding: 0.2rem 0.5rem; font-size: 0.8rem; font-family: monospace; background: hsl(var(--muted)); border: 1px solid hsl(var(--border)); border-radius: 4px; }
            .shortcut-item span { color: hsl(var(--muted-foreground)); font-size: 0.9rem; }
            @media (max-width: 768px) {
                .help-container { padding: 1.5rem 1rem; }
                .help-nav { padding: 0.75rem 1rem; flex-direction: column; gap: 0.75rem; }
                .shortcut-preview { flex-direction: column; gap: 1rem; }
            }
        }

        return page.toString()
    }

    // ---- GET /shortcuts — Keyboard shortcuts reference ----

    public func render_shortcuts_page() : string {
        var page = HtmlPage()
        page.defaultUniversalSetup()
        page.defaultPrepare()
        page.injectDefaultComponentsTheme()
        var title = std::string_view("Keyboard Shortcuts — Underlayer")
        page.appendTitle(&title)

        #html {
            <div class="help-page">
                <div class="help-nav">
                    <a href="/" class="nav-brand">Underlayer</a>
                    <div class="help-nav-links">
                        <a href="/help">Help</a>
                        <a href="/shortcuts" class="active">Shortcuts</a>
                        <a href="/faq">FAQ</a>
                        <a href="/about">About</a>
                    </div>
                </div>

                <div class="help-container">
                    <h1>Keyboard Shortcuts</h1>
                    <p class="help-subtitle">Navigate faster with keyboard shortcuts.</p>

                    <div class="shortcuts-grid">
                        <div class="shortcut-group">
                            <h2>Global</h2>
                            <table class="shortcut-table">
                                <tr><td><kbd>Ctrl</kbd> + <kbd>K</kbd></td><td>Open search</td></tr>
                                <tr><td><kbd>Ctrl</kbd> + <kbd>/</kbd></td><td>Open search (alternative)</td></tr>
                                <tr><td><kbd>?</kbd></td><td>Show keyboard shortcuts</td></tr>
                                <tr><td><kbd>Esc</kbd></td><td>Close modal, search, or overlay</td></tr>
                                <tr><td><kbd>g</kbd> then <kbd>h</kbd></td><td>Go to Home</td></tr>
                                <tr><td><kbd>g</kbd> then <kbd>d</kbd></td><td>Go to Dashboard</td></tr>
                                <tr><td><kbd>g</kbd> then <kbd>r</kbd></td><td>Go to Review</td></tr>
                                <tr><td><kbd>g</kbd> then <kbd>p</kbd></td><td>Go to Progress</td></tr>
                                <tr><td><kbd>g</kbd> then <kbd>c</kbd></td><td>Go to Courses</td></tr>
                            </table>
                        </div>

                        <div class="shortcut-group">
                            <h2>Navigation</h2>
                            <table class="shortcut-table">
                                <tr><td><kbd>[</kbd></td><td>Previous concept</td></tr>
                                <tr><td><kbd>]</kbd></td><td>Next concept</td></tr>
                                <tr><td><kbd>Backspace</kbd></td><td>Go back</td></tr>
                                <tr><td><kbd>Home</kbd></td><td>Go to first concept</td></tr>
                                <tr><td><kbd>End</kbd></td><td>Go to last concept</td></tr>
                            </table>
                        </div>

                        <div class="shortcut-group">
                            <h2>Review</h2>
                            <table class="shortcut-table">
                                <tr><td><kbd>1</kbd></td><td>Rate: Again</td></tr>
                                <tr><td><kbd>2</kbd></td><td>Rate: Hard</td></tr>
                                <tr><td><kbd>3</kbd></td><td>Rate: Good</td></tr>
                                <tr><td><kbd>4</kbd></td><td>Rate: Easy</td></tr>
                                <tr><td><kbd>Space</kbd></td><td>Show answer / Reveal</td></tr>
                                <tr><td><kbd>s</kbd></td><td>Skip current item</td></tr>
                                <tr><td><kbd>u</kbd></td><td>Undo last rating</td></tr>
                                <tr><td><kbd>p</kbd></td><td>Pause session</td></tr>
                            </table>
                        </div>

                        <div class="shortcut-group">
                            <h2>Lesson</h2>
                            <table class="shortcut-table">
                                <tr><td><kbd>←</kbd></td><td>Previous section</td></tr>
                                <tr><td><kbd>→</kbd></td><td>Next section</td></tr>
                                <tr><td><kbd>Enter</kbd></td><td>Submit answer</td></tr>
                                <tr><td><kbd>Tab</kbd></td><td>Next exercise option</td></tr>
                                <tr><td><kbd>Shift</kbd> + <kbd>Tab</kbd></td><td>Previous exercise option</td></tr>
                            </table>
                        </div>

                        <div class="shortcut-group">
                            <h2>Theme & Accessibility</h2>
                            <table class="shortcut-table">
                                <tr><td><kbd>t</kbd></td><td>Toggle dark/light theme</td></tr>
                                <tr><td><kbd>Ctrl</kbd> + <kbd>+</kbd></td><td>Increase font size</td></tr>
                                <tr><td><kbd>Ctrl</kbd> + <kbd>-</kbd></td><td>Decrease font size</td></tr>
                                <tr><td><kbd>Ctrl</kbd> + <kbd>0</kbd></td><td>Reset font size</td></tr>
                            </table>
                        </div>
                    </div>
                </div>
            </div>
        }

        #css {
            body { font-family: system-ui, sans-serif; line-height: 1.6; margin: 0; background: hsl(var(--background)); color: hsl(var(--foreground)); }
            .help-nav { background: hsl(var(--card)); border-bottom: 1px solid hsl(var(--border)); padding: 0.75rem 0; position: sticky; top: 0; z-index: 100; }
            .help-nav { max-width: 1200px; margin: 0 auto; padding: 0.75rem 2rem; display: flex; align-items: center; justify-content: space-between; }
            .nav-brand { font-size: 1.25rem; font-weight: 700; color: hsl(var(--foreground)); text-decoration: none; }
            .nav-brand:hover { color: hsl(217 91% 60%); text-decoration: none; }
            .help-nav-links { display: flex; gap: 1.5rem; }
            .help-nav-links a { color: hsl(var(--muted-foreground)); text-decoration: none; font-size: 0.9rem; font-weight: 500; padding: 0.5rem 0.75rem; border-radius: 6px; transition: all 0.15s; }
            .help-nav-links a:hover { color: hsl(var(--foreground)); background: hsl(var(--accent)); text-decoration: none; }
            .help-nav-links a.active { color: hsl(217 91% 60%); background: hsl(217 91% 60% / 10%); }
            .help-container { max-width: 900px; margin: 0 auto; padding: 3rem 2rem; }
            .help-container h1 { font-size: 2rem; margin-bottom: 0.5rem; color: hsl(var(--foreground)); }
            .help-subtitle { color: hsl(var(--muted-foreground)); font-size: 1.1rem; margin-bottom: 3rem; }
            .shortcuts-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(380px, 1fr)); gap: 2rem; }
            .shortcut-group h2 { font-size: 1.2rem; margin-bottom: 1rem; color: hsl(var(--foreground)); }
            .shortcut-table { width: 100%; border-collapse: collapse; }
            .shortcut-table td { padding: 0.5rem 0.75rem; border-bottom: 1px solid hsl(var(--border)); font-size: 0.9rem; }
            .shortcut-table td:first-child { white-space: nowrap; width: 50%; }
            .shortcut-table td:last-child { color: hsl(var(--muted-foreground)); }
            .shortcut-table tr:last-child td { border-bottom: none; }
            .shortcut-table kbd { display: inline-block; padding: 0.15rem 0.4rem; font-size: 0.8rem; font-family: monospace; background: hsl(var(--muted)); border: 1px solid hsl(var(--border)); border-radius: 4px; }
            @media (max-width: 768px) {
                .help-container { padding: 1.5rem 1rem; }
                .help-nav { padding: 0.75rem 1rem; flex-direction: column; gap: 0.75rem; }
                .shortcuts-grid { grid-template-columns: 1fr; }
            }
        }

        return page.toString()
    }

    // ---- GET /faq — FAQ page ----

    public func render_faq_page() : string {
        var page = HtmlPage()
        page.defaultUniversalSetup()
        page.defaultPrepare()
        page.injectDefaultComponentsTheme()
        var title = std::string_view("Frequently Asked Questions — Underlayer")
        page.appendTitle(&title)

        #html {
            <div class="help-page">
                <div class="help-nav">
                    <a href="/" class="nav-brand">Underlayer</a>
                    <div class="help-nav-links">
                        <a href="/help">Help</a>
                        <a href="/shortcuts">Shortcuts</a>
                        <a href="/faq" class="active">FAQ</a>
                        <a href="/about">About</a>
                    </div>
                </div>

                <div class="help-container">
                    <h1>Frequently Asked Questions</h1>
                    <p class="help-subtitle">Quick answers to common questions.</p>

                    <div class="faq-list">
                        <div class="faq-item">
                            <h3>What is Underlayer?</h3>
                            <p>Underlayer is a learning platform designed for deep understanding of technical subjects. Unlike typical course platforms, every concept is verified against authoritative sources, taught from first principles, and reinforced through spaced repetition.</p>
                        </div>

                        <div class="faq-item">
                            <h3>Is Underlayer free?</h3>
                            <p>Yes. Underlayer is open source and free to use. Create an account to save your progress across devices.</p>
                        </div>

                        <div class="faq-item">
                            <h3>How does spaced repetition work?</h3>
                            <p>Underlayer uses FSRS (Free Spaced Repetition Scheduler), an algorithm that calculates the optimal time to review each concept based on your past performance. It adapts to your individual memory patterns — concepts you find easy are shown less often, while difficult ones appear more frequently.</p>
                        </div>

                        <div class="faq-item">
                            <h3>What is Knowledge Health?</h3>
                            <p>Knowledge Health is a score (0-100) that estimates how well you've retained all concepts you've studied. It factors in review accuracy, time since last review, and difficulty ratings. A score above 80 means your knowledge is stable.</p>
                        </div>

                        <div class="faq-item">
                            <h3>Can I use Underlayer offline?</h3>
                            <p>Yes. Course content is compiled to static HTML/CSS/JS files. You can download them and study without an internet connection. Progress will be saved to localStorage and synced when you're back online.</p>
                        </div>

                        <div class="faq-item">
                            <h3>Why does Underlayer only have the ELF course right now?</h3>
                            <p>Underlayer prioritizes depth over volume. Each course goes through rigorous verification against authoritative sources (specs, RFCs, source code). We'd rather have one excellent course than a hundred mediocre ones. More courses are being developed.</p>
                        </div>

                        <div class="faq-item">
                            <h3>What are the review modes?</h3>
                            <p>Underlayer offers multiple review modes: Quick Review (fast refresh), Deep Review (thorough testing), Weakness Focus (targeted at weak concepts), and more. Choose based on your available time and learning goals.</p>
                        </div>

                        <div class="faq-item">
                            <h3>Can I export my data?</h3>
                            <p>Yes. Visit <a href="/settings">Settings</a> to export your progress, review history, and analytics as JSON. Your data belongs to you.</p>
                        </div>

                        <div class="faq-item">
                            <h3>How do I report a bug or suggest a feature?</h3>
                            <p>Open an issue on <a href="https://github.com/anomalyco/opencode/issues">GitHub</a>. Include as much detail as possible: what you were doing, what you expected, and what actually happened.</p>
                        </div>

                        <div class="faq-item">
                            <h3>What technologies does Underlayer use?</h3>
                            <p>Underlayer is built with the Chemical programming language, uses SQLite (or Turso) for the database, and compiles course content to static HTML. See the <a href="/about">About</a> page for more details.</p>
                        </div>

                        <div class="faq-item">
                            <h3>Is my data private?</h3>
                            <p>Yes. Underlayer does not track you, sell your data, or use analytics services. Your progress is stored in your account and nowhere else. You can delete your account and all data at any time from Settings.</p>
                        </div>
                    </div>
                </div>
            </div>
        }

        #css {
            body { font-family: system-ui, sans-serif; line-height: 1.6; margin: 0; background: hsl(var(--background)); color: hsl(var(--foreground)); }
            .help-nav { background: hsl(var(--card)); border-bottom: 1px solid hsl(var(--border)); padding: 0.75rem 0; position: sticky; top: 0; z-index: 100; }
            .help-nav { max-width: 1200px; margin: 0 auto; padding: 0.75rem 2rem; display: flex; align-items: center; justify-content: space-between; }
            .nav-brand { font-size: 1.25rem; font-weight: 700; color: hsl(var(--foreground)); text-decoration: none; }
            .nav-brand:hover { color: hsl(217 91% 60%); text-decoration: none; }
            .help-nav-links { display: flex; gap: 1.5rem; }
            .help-nav-links a { color: hsl(var(--muted-foreground)); text-decoration: none; font-size: 0.9rem; font-weight: 500; padding: 0.5rem 0.75rem; border-radius: 6px; transition: all 0.15s; }
            .help-nav-links a:hover { color: hsl(var(--foreground)); background: hsl(var(--accent)); text-decoration: none; }
            .help-nav-links a.active { color: hsl(217 91% 60%); background: hsl(217 91% 60% / 10%); }
            .help-container { max-width: 800px; margin: 0 auto; padding: 3rem 2rem; }
            .help-container h1 { font-size: 2rem; margin-bottom: 0.5rem; color: hsl(var(--foreground)); }
            .help-subtitle { color: hsl(var(--muted-foreground)); font-size: 1.1rem; margin-bottom: 3rem; }
            .faq-list { display: flex; flex-direction: column; gap: 1rem; }
            .faq-item { background: hsl(var(--card)); border: 1px solid hsl(var(--border)); border-radius: 10px; padding: 1.25rem; }
            .faq-item h3 { font-size: 1.05rem; margin: 0 0 0.5rem 0; color: hsl(var(--foreground)); }
            .faq-item p { margin: 0.5rem 0; color: hsl(var(--muted-foreground)); font-size: 0.95rem; }
            .faq-item a { color: hsl(217 91% 60%); text-decoration: none; }
            .faq-item a:hover { text-decoration: underline; }
            @media (max-width: 768px) {
                .help-container { padding: 1.5rem 1rem; }
                .help-nav { padding: 0.75rem 1rem; flex-direction: column; gap: 0.75rem; }
            }
        }

        return page.toString()
    }

    // ---- GET /about — About page ----

    public func render_about_page() : string {
        var page = HtmlPage()
        page.defaultUniversalSetup()
        page.defaultPrepare()
        page.injectDefaultComponentsTheme()
        var title = std::string_view("About Underlayer")
        page.appendTitle(&title)

        #html {
            <div class="help-page">
                <div class="help-nav">
                    <a href="/" class="nav-brand">Underlayer</a>
                    <div class="help-nav-links">
                        <a href="/help">Help</a>
                        <a href="/shortcuts">Shortcuts</a>
                        <a href="/faq">FAQ</a>
                        <a href="/about" class="active">About</a>
                    </div>
                </div>

                <div class="help-container">
                    <h1>About Underlayer</h1>
                    <p class="help-subtitle">Learn things deeply.</p>

                    <div class="about-section">
                        <h2>Mission</h2>
                        <p>Underlayer exists to solve a problem: most technical education is shallow. Courses rush through topics, skip foundational understanding, and rely on re-reading instead of active learning.</p>
                        <p>Underlayer takes a different approach. Every concept is taught from first principles, verified against authoritative sources, and tested until it sticks. We believe that understanding — not just exposure — is the goal of education.</p>
                    </div>

                    <div class="about-section">
                        <h2>How It Works</h2>
                        <div class="about-cards">
                            <div class="about-card">
                                <h3>Structured Learning</h3>
                                <p>Each concept follows a consistent structure: Why it exists, how to model it, the real-world details, concrete examples, and connections to other concepts. This ensures you understand not just what, but why.</p>
                            </div>
                            <div class="about-card">
                                <h3>Active Recall</h3>
                                <p>After every lesson, exercises test your understanding. This isn't optional — it's how learning happens. Struggle is expected and normal.</p>
                            </div>
                            <div class="about-card">
                                <h3>Spaced Repetition</h3>
                                <p>The FSRS v4 algorithm schedules reviews at the exact moment you're about to forget. This means minimal review time for maximum retention.</p>
                            </div>
                            <div class="about-card">
                                <h3>Deep Verification</h3>
                                <p>Every hex dump, byte offset, and struct layout is verified against real specifications (gABI, ELF spec) or actual tool output (readelf, objdump). No invented data.</p>
                            </div>
                        </div>
                    </div>

                    <div class="about-section">
                        <h2>The FSRS Algorithm</h2>
                        <p>FSRS (Free Spaced Repetition Scheduler) is the algorithm behind Underlayer's review scheduling. Unlike older algorithms (SM-2, Anki's default), FSRS models human memory as a multi-component system:</p>
                        <ul>
                            <li><strong>Stability</strong> — How long until you forget (in days)</li>
                            <li><strong>Difficulty</strong> — How inherently hard the concept is for you</li>
                            <li><strong>Retrievability</strong> — Current probability of recall</li>
                        </ul>
                        <p>After each review, FSRS updates these parameters and calculates the next optimal review time. The algorithm adapts to your individual memory patterns, not just population averages.</p>
                    </div>

                    <div class="about-section">
                        <h2>Technology</h2>
                        <p>Underlayer is built from scratch using the <strong>Chemical</strong> programming language. Here's what powers it:</p>
                        <div class="tech-grid">
                            <div class="tech-item">
                                <strong>Chemical</strong>
                                <p>The programming language used for all platform code. Designed for educational tools.</p>
                            </div>
                            <div class="tech-item">
                                <strong>SQLite / Turso</strong>
                                <p>Dual-backend database: SQLite for local development, Turso (HTTP) for production. Same code, same queries.</p>
                            </div>
                            <div class="tech-item">
                                <strong>Static HTML</strong>
                                <p>Course content compiles to static HTML/CSS/JS. Works offline, loads fast, no JavaScript framework required.</p>
                            </div>
                            <div class="tech-item">
                                <strong>Open Source</strong>
                                <p>Built in public, verified by the community. Every design decision is documented and justified.</p>
                            </div>
                        </div>
                    </div>

                    <div class="about-section">
                        <h2>Principles</h2>
                        <div class="principles-list">
                            <div class="principle">
                                <strong>Depth over volume.</strong> One excellent course beats 100 mediocre ones.
                            </div>
                            <div class="principle">
                                <strong>Verify everything.</strong> AI-generated content is presumed incorrect until verified against authoritative sources.
                            </div>
                            <div class="principle">
                                <strong>Learning is the product.</strong> Every feature must answer: "Does this help someone understand something deeply?"
                            </div>
                            <div class="principle">
                                <strong>No passive reading.</strong> Every concept must be followed by active use.
                            </div>
                            <div class="principle">
                                <strong>Normalize struggle.</strong> Show "This is supposed to be hard" not "You're failing."
                            </div>
                            <div class="principle">
                                <strong>Your data is yours.</strong> Export everything. Delete everything. No tracking, no ads, no selling data.
                            </div>
                        </div>
                    </div>

                    <div class="about-section">
                        <h2>Open Source</h2>
                        <p>Underlayer is open source software. You can view the source code, report issues, and contribute on <a href="https://github.com/anomalyco/opencode">GitHub</a>.</p>
                    </div>
                </div>
            </div>
        }

        #css {
            body { font-family: system-ui, sans-serif; line-height: 1.6; margin: 0; background: hsl(var(--background)); color: hsl(var(--foreground)); }
            .help-nav { background: hsl(var(--card)); border-bottom: 1px solid hsl(var(--border)); padding: 0.75rem 0; position: sticky; top: 0; z-index: 100; }
            .help-nav { max-width: 1200px; margin: 0 auto; padding: 0.75rem 2rem; display: flex; align-items: center; justify-content: space-between; }
            .nav-brand { font-size: 1.25rem; font-weight: 700; color: hsl(var(--foreground)); text-decoration: none; }
            .nav-brand:hover { color: hsl(217 91% 60%); text-decoration: none; }
            .help-nav-links { display: flex; gap: 1.5rem; }
            .help-nav-links a { color: hsl(var(--muted-foreground)); text-decoration: none; font-size: 0.9rem; font-weight: 500; padding: 0.5rem 0.75rem; border-radius: 6px; transition: all 0.15s; }
            .help-nav-links a:hover { color: hsl(var(--foreground)); background: hsl(var(--accent)); text-decoration: none; }
            .help-nav-links a.active { color: hsl(217 91% 60%); background: hsl(217 91% 60% / 10%); }
            .help-container { max-width: 800px; margin: 0 auto; padding: 3rem 2rem; }
            .help-container h1 { font-size: 2rem; margin-bottom: 0.5rem; color: hsl(var(--foreground)); }
            .help-subtitle { color: hsl(var(--muted-foreground)); font-size: 1.1rem; margin-bottom: 3rem; }
            .about-section { margin-bottom: 3rem; }
            .about-section h2 { font-size: 1.4rem; margin-bottom: 1rem; color: hsl(var(--foreground)); padding-bottom: 0.5rem; border-bottom: 1px solid hsl(var(--border)); }
            .about-section p { color: hsl(var(--muted-foreground)); font-size: 0.95rem; margin-bottom: 1rem; }
            .about-section ul { margin: 0.5rem 0 1rem 1.5rem; color: hsl(var(--muted-foreground)); font-size: 0.95rem; }
            .about-section li { margin-bottom: 0.35rem; }
            .about-section a { color: hsl(217 91% 60%); text-decoration: none; }
            .about-section a:hover { text-decoration: underline; }
            .about-cards { display: grid; grid-template-columns: repeat(auto-fill, minmax(350px, 1fr)); gap: 1rem; margin-top: 1rem; }
            .about-card { background: hsl(var(--card)); border: 1px solid hsl(var(--border)); border-radius: 10px; padding: 1.25rem; }
            .about-card h3 { font-size: 1.05rem; margin: 0 0 0.5rem 0; color: hsl(var(--foreground)); }
            .about-card p { margin: 0.5rem 0; color: hsl(var(--muted-foreground)); font-size: 0.9rem; }
            .tech-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(350px, 1fr)); gap: 1rem; margin-top: 1rem; }
            .tech-item { background: hsl(var(--card)); border: 1px solid hsl(var(--border)); border-radius: 10px; padding: 1.25rem; }
            .tech-item strong { display: block; margin-bottom: 0.35rem; color: hsl(var(--foreground)); }
            .tech-item p { margin: 0.25rem 0; color: hsl(var(--muted-foreground)); font-size: 0.9rem; }
            .principles-list { display: flex; flex-direction: column; gap: 0.75rem; }
            .principle { background: hsl(var(--card)); border: 1px solid hsl(var(--border)); border-radius: 10px; padding: 1rem 1.25rem; }
            .principle strong { color: hsl(var(--foreground)); }
            @media (max-width: 768px) {
                .help-container { padding: 1.5rem 1rem; }
                .help-nav { padding: 0.75rem 1rem; flex-direction: column; gap: 0.75rem; }
                .about-cards { grid-template-columns: 1fr; }
                .tech-grid { grid-template-columns: 1fr; }
            }
        }

        return page.toString()
    }

    // ---- Handler functions ----

    public func handle_help_page(req : &http::Request, res : *mut http::ResponseWriter) {
        var html = render_help_page()
        var ct = std::string_view("text/html; charset=utf-8")
        res.set_header_view(std::string_view("Content-Type"), &ct)
        var hv = html.to_view()
        res.write_view(&hv)
    }

    public func handle_shortcuts_page(req : &http::Request, res : *mut http::ResponseWriter) {
        var html = render_shortcuts_page()
        var ct = std::string_view("text/html; charset=utf-8")
        res.set_header_view(std::string_view("Content-Type"), &ct)
        var hv = html.to_view()
        res.write_view(&hv)
    }

    public func handle_faq_page(req : &http::Request, res : *mut http::ResponseWriter) {
        var html = render_faq_page()
        var ct = std::string_view("text/html; charset=utf-8")
        res.set_header_view(std::string_view("Content-Type"), &ct)
        var hv = html.to_view()
        res.write_view(&hv)
    }

    public func handle_about_page(req : &http::Request, res : *mut http::ResponseWriter) {
        var html = render_about_page()
        var ct = std::string_view("text/html; charset=utf-8")
        res.set_header_view(std::string_view("Content-Type"), &ct)
        var hv = html.to_view()
        res.write_view(&hv)
    }

}
