# Underlayer Components Skill

## Available Components (from `lang/libs/components`)

Underlayer can use the shadcn-style component library. Import via `import components` in `chemical.mod`.

> **⚠ Implementation status (verified 2026-09-17):** the `components` library is imported by the root `chemical.mod` and by `web/`, and the required page setup calls (`defaultUniversalSetup`, `defaultPrepare`, `injectDefaultComponentsTheme` — used in 20 web files) are applied on every platform page. However, **no page in this repo currently renders the JSX-style components below** — all platform pages use plain HTML (`<div class="navbar">...`) inside `#html { }` with scoped `#css`, and interactivity is vanilla JS in `#js { }`. A `/components` demo page (plain-HTML scroll area, resizable panel, theme preview, font upload) exists as a UI pattern reference. Treat the component examples here as the target style for new interactive widgets, and check `implementation_gaps` for known `#universal` bugs before relying on stateful components. Plain HTML + scoped `#css` remains the safe default.

### Core Components for Learning Platform

| Component | Use Case in Underlayer |
|-----------|----------------------|
| `Card`, `CardHeader`, `CardTitle`, `CardContent`, `CardBody`, `CardFooter` | Lesson cards, concept cards, course cards |
| `Button`, `ButtonPrimary`, `ButtonGhost` | Quiz answers, navigation, actions |
| `Badge`, `BadgeSuccess`, `BadgeWarning`, `BadgeError` | Mastery status, difficulty labels |
| `Progress` | Learning progress, concept mastery bars |
| `Alert`, `AlertInfo`, `AlertSuccess`, `AlertError` | Quiz feedback, error messages |
| `Tabs`, `TabList`, `Tab`, `TabPanel` | Course modules, lesson sections |
| `Accordion`, `AccordionItem` | Expandable lesson content, FAQ |
| `Collapsible` | Expandable code blocks, hints |
| `Tooltip` | Hex field explanations, term definitions |
| `Dialog`, `DialogContent`, `DialogHeader` | Review session modal, settings |
| `Toast`, `Toaster` | Achievement notifications, save confirmations |
| `Input`, `TextArea` | Learner notes, search |
| `Select`, `NativeSelect` | Course filter, difficulty selection |
| `Separator` | Visual breaks between sections |
| `Skeleton`, `Spinner` | Loading states |
| `Container`, `Stack`, `Grid` | Page layout |
| `Breadcrumbs` | Navigation hierarchy |
| `H1`-`H6`, `Text`, `Lead`, `Caption`, `CodeText` | Typography |
| `Kbd` | Keyboard shortcut hints |
| `Table`, `TableHeadCell`, `TableCell` | Data display (ELF header fields) |

### Theme Injection

Always inject the theme before using components (this exact sequence appears in every handler in `web/src/`):

```chemical
var page = HtmlPage()
page.defaultUniversalSetup()          // hydration runtime for #universal components
page.defaultPrepare()                 // charset + viewport
page.injectDefaultComponentsTheme()   // shadcn theme CSS tokens
page.appendTitle(std::string_view("..."))
// ... #html / #css / #js ...
return page.toString()
```

Note the camelCase method names — that is what compiles in this codebase (`snake_case` variants like `default_prepare()` shown in older docs will not).

### Component Pattern in Underlayer

```chemical
import components

public func render_concept() : std::string {
    var page = HtmlPage()
    page.defaultUniversalSetup()     // hydration runtime
    page.defaultPrepare()            // charset + viewport
    page.injectDefaultComponentsTheme()  // shadcn theme tokens

    #html {
        <Container size="default">
            <Stack direction="column" gap="lg">
                <Card>
                    <CardBody>
                        <H1>{concept_title}</H1>
                        <Text muted>{concept_description}</Text>
                    </CardBody>
                </Card>

                <Card>
                    <CardHeader>
                        <CardTitle level={3}>Check Your Understanding</CardTitle>
                    </CardHeader>
                    <CardBody>
                        <Stack direction="column" gap="sm">
                            <Button variant="outline" onClick={...}>{option_a}</Button>
                            <Button variant="outline" onClick={...}>{option_b}</Button>
                            <Button variant="outline" onClick={...}>{option_c}</Button>
                        </Stack>
                    </CardBody>
                </Card>
            </Stack>
        </Container>
    }

    #css { /* scoped styles */ }
    #js { /* interactivity */ }

    return page.toString()
}
```

## Reusable Underlayer Components

### ConceptCard

Displays a concept with title, description, and mastery status.

```chemical
#universal ConceptCard(props) {
    var title = props.title
    var description = props.description
    var status = props.status  // "unlearned", "learning", "reviewing", "mastered"
    var href = props.href

    #html {
        <Card onClick={...}>
            <CardBody>
                <Stack direction="row" justify="space-between" align="center">
                    <Stack direction="column" gap="xs">
                        <CardTitle level={4}>{title}</CardTitle>
                        <Text muted>{description}</Text>
                    </Stack>
                    <Badge variant={status == "mastered" ? "success" : status == "learning" ? "warning" : "default"}>
                        {status}
                    </Badge>
                </Stack>
            </CardBody>
        </Card>
    }
}
```

### QuizWidget

Interactive quiz with multiple choice answers and feedback.

```chemical
#universal QuizWidget(props) {
    state selected = -1
    state answered = false
    var correct = props.correct_index
    var options = props.options

    #html {
        <Card>
            <CardHeader>
                <CardTitle level={3}>{props.question}</CardTitle>
            </CardHeader>
            <CardBody>
                <Stack direction="column" gap="sm">
                    @{var i = 0
                    while(i < options.size()) {
                        var idx = i
                        var is_correct = idx == correct
                        var variant = "outline"
                        if(answered) {
                            if(idx == selected && is_correct) { variant = "success" }
                            else if(idx == selected && !is_correct) { variant = "destructive" }
                            else if(is_correct) { variant = "success" }
                        }
                        #html {
                            <Button variant={variant} onClick={...}>{options.get(idx)}</Button>
                        }
                        i = i + 1
                    }}
                </Stack>
                @{if(answered) {
                    #html {
                        <Alert variant={selected == correct ? "success" : "error"}>
                            <AlertTitle>{selected == correct ? "Correct!" : "Not quite."}</AlertTitle>
                            <AlertBody>{props.explanation}</AlertBody>
                        </Alert>
                    }
                }}
            </CardBody>
        </Card>
    }
}
```

### MasteryProgress

Visual progress bar showing mastery across concepts.

```chemical
#universal MasteryProgress(props) {
    var mastered = props.mastered
    var total = props.total
    var pct = if(total > 0) { (mastered * 100) / total } else { 0 }

    #html {
        <Card>
            <CardBody>
                <Stack direction="column" gap="sm">
                    <Stack direction="row" justify="space-between">
                        <Text>Course Progress</Text>
                        <Caption>{mastered}/{total} concepts</Caption>
                    </Stack>
                    <Progress value={pct} max={100} variant="success" showValue={true} suffix="%" />
                </Stack>
            </CardBody>
        </Card>
    }
}
```

### LessonNav

Navigation between lessons with prev/next.

```chemical
#universal LessonNav(props) {
    #html {
        <Stack direction="row" justify="space-between" align="center">
            @{if(props.prev_id.size() > 0) {
                #html {
                    <Button variant="ghost" onClick={...}>
                        ← {props.prev_title}
                    </Button>
                }
            } @else {
                #html { <div></div> }
            }}
            @{if(props.next_id.size() > 0) {
                #html {
                    <Button variant="default" onClick={...}>
                        {props.next_title} →
                    </Button>
                }
            } @else {
                #html { <div></div> }
            }}
        </Stack>
    }
}
```

### ReviewSessionCard

Card for a single review item during spaced repetition.

```chemical
#universal ReviewSessionCard(props) {
    state show_answer = false

    #html {
        <Card>
            <CardHeader>
                <Stack direction="row" justify="space-between" align="center">
                    <CardTitle level={4}>{props.front}</CardTitle>
                    <Badge variant="info">{props.exercise_type}</Badge>
                </Stack>
            </CardHeader>
            <CardBody>
                @{if(!show_answer) {
                    #html {
                        <Button variant="default" onClick={...}>Show Answer</Button>
                    }
                } @else {
                    #html {
                        <Stack direction="column" gap="md">
                            <Alert variant="info">
                                <AlertTitle>Answer</AlertTitle>
                                <AlertBody>{props.back}</AlertBody>
                            </Alert>
                            <Separator />
                            <Text muted>How well did you know this?</Text>
                            <Stack direction="row" gap="sm">
                                <Button variant="destructive" onClick={...}>Again</Button>
                                <Button variant="outline" onClick={...}>Hard</Button>
                                <Button variant="default" onClick={...}>Good</Button>
                                <Button variant="success" onClick={...}>Easy</Button>
                            </Stack>
                        </Stack>
                    }
                }}
            </CardBody>
        </Card>
    }
}
```

### CourseHeader

Header for course landing page with title, description, and stats.

```chemical
#universal CourseHeader(props) {
    #html {
        <Stack direction="column" gap="md">
            <H1>{props.title}</H1>
            <Lead>{props.description}</Lead>
            <Stack direction="row" gap="md">
                <Badge variant="secondary">{props.module_count} modules</Badge>
                <Badge variant="secondary">{props.concept_count} concepts</Badge>
                <Badge variant="info">{props.version}</Badge>
            </Stack>
        </Stack>
    }
}
```

## Layout Patterns

### Page Layout

```chemical
var page = HtmlPage()
page.defaultPrepare()
page.injectDefaultComponentsTheme()

#html {
    <Container size="lg">
        <Stack direction="column" gap="xl" style="padding: 2rem 0">
            {content}
        </Stack>
    </Container>
}
```

### Responsive Grid

```chemical
#html {
    <Grid cols={3} gap="md">
        @{var i = 0
        while(i < concepts.size()) {
            var c = concepts.get_ptr(i)
            #html {
                <ConceptCard title={c.title} description={c.description} status={c.status} />
            }
            i = i + 1
        }}
    </Grid>
}
```

### Sidebar + Content

```chemical
#html {
    <Stack direction="row" gap="lg">
        <div style="width: 280px; flex-shrink: 0">
            {sidebar}
        </div>
        <div style="flex: 1">
            {content}
        </div>
    </Stack>
}
```
