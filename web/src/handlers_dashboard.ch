// underlayer_web — Dashboard handler with universal components.
using std::string
using std::vector
using underlayer_db::DbClient

public namespace underlayer_web {

    // 7.2.4, 7.2.5, 1.5.20: Dashboard with progress, knowledge health, and stats
    public func handle_dashboard(db : &DbClient, courses_dir : &string, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = string("demo")
        var course_id = string("elf")

        // Get knowledge health
        var states = underlayer_repository::get_all_concept_states(&raw db, &learner_id, &course_id)
        var health = underlayer_learning::compute_knowledge_health(&raw states)
        var depth = underlayer_learning::compute_depth_score(&raw states)
        var breadth = underlayer_learning::compute_breadth_score(&raw states, health.total_concepts)

        // Get due items count
        var due_items = underlayer_repository::get_due_review_items(&raw db, &learner_id, &course_id, 1000)
        var new_count = 0
        var due_count = 0
        var i : size_t = 0
        while(i < due_items.size()) {
            var item = due_items.get_ptr(i)
            if(item.last_review == 0) { new_count = new_count + 1 }
            else { due_count = due_count + 1 }
            i = i + 1
        }

        // Build page with components
        var page = HtmlPage()
        page.defaultUniversalSetup()
        page.defaultPrepare()
        page.injectDefaultComponentsTheme()
        page.appendTitle(std::string_view("Dashboard — Underlayer"))

        #html {
            <div class="navbar">
                <div class="nav-inner">
                    <a href="/" class="nav-brand">Underlayer</a>
                    <div class="nav-links">
                        <a href="/" class="nav-link">Home</a>
                        <a href="/courses/elf" class="nav-link">Courses</a>
                        <a href="/dashboard" class="nav-link active">Dashboard</a>
                        <a href="/review" class="nav-link">Review</a>
                        <a href="/progress" class="nav-link">Progress</a>
                    </div>
                </div>
            </div>

            <div class="container" style="max-width: 1200px; margin: 0 auto; padding: 2rem;">
                <div style="margin-bottom: 2rem;">
                    <H1>Dashboard</H1>
                    <Text variant="muted">Welcome back to your learning journey</Text>
                </div>

                <div style="display: grid; grid-template-columns: repeat(4, 1fr); gap: 1rem; margin-bottom: 2rem;">
                    <Card>
                        <CardBody>
                            <Text variant="muted">Total Concepts</Text>
                            <Text style="font-size: 2rem; font-weight: bold;">{health.total_concepts}</Text>
                        </CardBody>
                    </Card>
                    <Card>
                        <CardBody>
                            <Text variant="muted">Mastered</Text>
                            <Text style="font-size: 2rem; font-weight: bold; color: var(--primary);">{health.mastered}</Text>
                        </CardBody>
                    </Card>
                    <Card>
                        <CardBody>
                            <Text variant="muted">Learning</Text>
                            <Text style="font-size: 2rem; font-weight: bold; color: var(--accent);">{health.learning}</Text>
                        </CardBody>
                    </Card>
                    <Card>
                        <CardBody>
                            <Text variant="muted">Reviewing</Text>
                            <Text style="font-size: 2rem; font-weight: bold; color: var(--destructive);">{health.reviewing}</Text>
                        </CardBody>
                    </Card>
                </div>

                <div style="display: grid; grid-template-columns: 2fr 1fr; gap: 1rem;">
                    <Card>
                        <CardHeader>
                            <CardTitle>Knowledge Health</CardTitle>
                        </CardHeader>
                        <CardBody>
                            <div style="margin-bottom: 1rem;">
                                <Text>Health Score</Text>
                                <Progress value={health.health_score * 100.0} max={100.0} variant="success" />
                                <Caption>{health.health_score * 100.0}% mastered</Caption>
                            </div>
                            <div style="margin-bottom: 1rem;">
                                <Text>Depth Score</Text>
                                <Progress value={depth} max={100.0} variant="info" />
                                <Caption>{depth}% understanding</Caption>
                            </div>
                            <div>
                                <Text>Breadth Score</Text>
                                <Progress value={breadth} max={100.0} variant="accent" />
                                <Caption>{breadth}% coverage</Caption>
                            </div>
                        </CardBody>
                    </Card>

                    <Card>
                        <CardHeader>
                            <CardTitle>Review Queue</CardTitle>
                        </CardHeader>
                        <CardBody>
                            <div style="margin-bottom: 1rem;">
                                <Badge variant="info">New: {new_count}</Badge>
                            </div>
                            <div style="margin-bottom: 1rem;">
                                <Badge variant="warning">Due: {due_count}</Badge>
                            </div>
                            <div>
                                <Badge variant="success">Mastered: {health.mastered}</Badge>
                            </div>
                            <div style="margin-top: 1rem;">
                                <Button variant="primary">Start Review</Button>
                            </div>
                        </CardBody>
                    </Card>
                </div>
            </div>
        }

        #css {
            [data-chx-i] { display: contents; }
            .container { font-family: system-ui, sans-serif; }
            .navbar { background: #ffffff; border-bottom: 1px solid #e5e7eb; padding: 0.75rem 0; position: sticky; top: 0; z-index: 100; }
            .nav-inner { max-width: 1200px; margin: 0 auto; padding: 0 2rem; display: flex; align-items: center; justify-content: space-between; }
            .nav-brand { font-size: 1.25rem; font-weight: 700; color: #111827; text-decoration: none; }
            .nav-brand:hover { color: #3b82f6; }
            .nav-links { display: flex; gap: 1.5rem; }
            .nav-link { color: #6b7280; text-decoration: none; font-size: 0.9rem; font-weight: 500; padding: 0.5rem 0.75rem; border-radius: 6px; transition: all 0.15s; }
            .nav-link:hover { color: #111827; background: #f3f4f6; }
            .nav-link.active { color: #3b82f6; background: #eff6ff; }
        }

        var html_out = page.toString()
        var bv = html_out.to_view()
        res.set_header_view(std::string_view("Content-Type"), &std::string_view("text/html; charset=utf-8"))
        res.write_view(&bv)
    }

}
