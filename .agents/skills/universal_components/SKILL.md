# Underlayer Universal Components Skill

## How Universal Components Work in Underlayer

Universal components provide SSR + hydration: the component renders on the server (HTML),
then hydrates on the client (interactive JS). This is the recommended pattern for
interactive course content.

### Key Rules

1. **Always inject theme first**: `page.inject_default_components_theme()`
2. **Use `#html` for JSX**: Never build HTML with string concatenation
3. **Use `#css` for styles**: Hashed class names, scoped to the component
4. **Use `#js` for client logic**: Only when needed for interactivity
5. **State must be declared with `state`**: Not `var` — `state` creates a signal
6. **Conditional UI uses JSX conditionals**: `{cond && <jsx/>}` not `if` statements

### Component File Structure

```chemical
import components
import page
import html_cbi
import css_cbi
import js_cbi

public func render_concept() : std::string {
    var page = HtmlPage()
    page.defaultUniversalSetup()     // hydration runtime for #universal components
    page.defaultPrepare()            // charset + viewport
    page.injectDefaultComponentsTheme()  // shadcn theme CSS tokens

    #html {
        <Container size="lg">
            <Stack direction="column" gap="xl">
                <!-- Content here -->
            </Stack>
        </Container>
    }

    #css {
        .lesson { max-width: 800px; margin: 0 auto; padding: 2rem; }
    }

    #js {
        // Client-side interactivity
    }

    return page.toString()
}
```

### State Management

```chemical
#universal MyComponent(props) {
    state count = 0
    state selected = ""
    state items = props.items  // initialize from props

    // Computed values
    var display = `${count} items`

    #html {
        <div>
            <Button onClick={...}>Click me</Button>
            <Text>{display}</Text>
        </div>
    }
}
```

### Event Handling

```chemical
#html {
    <Button onClick={...}>Click</Button>
    <Input onChange={...} />
    <Select onValueChange={...} />
}
```

### Lists and Loops

```chemical
#html {
    <Stack direction="column" gap="sm">
        @{var i = 0
        while(i < items.size()) {
            var item = items.get_ptr(i)
            #html {
                <Card key={item.id}>
                    <CardBody>
                        <Text>{item.title}</Text>
                    </CardBody>
                </Card>
            }
            i = i + 1
        }}
    </Stack>
}
```

### Conditional Rendering

```chemical
#html {
    <div>
        @{if(show_details) {
            #html {
                <Alert variant="info">
                    <AlertBody>{details}</AlertBody>
                </Alert>
            }
        } @else {
            #html {
                <Button onClick={...}>Show Details</Button>
            }
        }}
    </div>
}
```

## Underlayer-Specific Patterns

### Quiz Pattern

```chemical
#universal QuizWidget(props) {
    state selected = -1
    state answered = false
    var correct = props.correct_index

    #html {
        <Card>
            <CardBody>
                <Stack direction="column" gap="md">
                    <Text>{props.question}</Text>
                    @{var i = 0
                    while(i < props.options.size()) {
                        var idx = i
                        var variant = "outline"
                        if(answered && idx == selected) {
                            if(idx == correct) { variant = "success" }
                            else { variant = "destructive" }
                        }
                        if(answered && idx == correct) { variant = "success" }
                        #html {
                            <Button
                                variant={variant}
                                disabled={answered}
                                onClick={...}
                            >{props.options.get(idx)}</Button>
                        }
                        i = i + 1
                    }}
                    @{if(answered) {
                        #html {
                            <Alert variant={selected == correct ? "success" : "error"}>
                                <AlertBody>{props.explanation}</AlertBody>
                            </Alert>
                        }
                    }}
                </Stack>
            </CardBody>
        </Card>
    }
}
```

### Progress Tracking Pattern

```chemical
#universal ProgressTracker(props) {
    state mastered = props.mastered
    state total = props.total
    var pct = if(total > 0) { (mastered * 100) / total } else { 0 }

    #html {
        <Card>
            <CardBody>
                <Stack direction="column" gap="sm">
                    <Stack direction="row" justify="space-between">
                        <Text>Progress</Text>
                        <Caption>{mastered}/{total}</Caption>
                    </Stack>
                    <Progress value={pct} max={100} variant="success" />
                </Stack>
            </CardBody>
        </Card>
    }
}
```

### Review Session Pattern

```chemical
#universal ReviewSession(props) {
    state current = 0
    state show_answer = false
    state rating = -1
    var items = props.items

    #html {
        <Card>
            <CardBody>
                @{if(current < items.size()) {
                    var item = items.get_ptr(current)
                    #html {
                        <Stack direction="column" gap="md">
                            <Text>{item.front}</Text>
                            @{if(!show_answer) {
                                #html {
                                    <Button onClick={...}>Show Answer</Button>
                                }
                            } @else {
                                #html {
                                    <Stack direction="column" gap="sm">
                                        <Alert variant="info">
                                            <AlertBody>{item.back}</AlertBody>
                                        </Alert>
                                        <Stack direction="row" gap="sm">
                                            <Button variant="destructive" onClick={...}>Again</Button>
                                            <Button variant="outline" onClick={...}>Hard</Button>
                                            <Button variant="default" onClick={...}>Good</Button>
                                            <Button variant="success" onClick={...}>Easy</Button>
                                        </Stack>
                                    </Stack>
                                }
                            }}
                        </Stack>
                    }
                } @else {
                    #html {
                        <Alert variant="success">
                            <AlertTitle>Session Complete!</AlertTitle>
                            <AlertBody>You reviewed {items.size()} items.</AlertBody>
                        </Alert>
                    }
                }}
            </CardBody>
        </Card>
    }
}
```

### Navigation Pattern

```chemical
#universal LessonNav(props) {
    #html {
        <Stack direction="row" justify="space-between" align="center">
            @{if(props.prev_id.size() > 0) {
                #html {
                    <Button variant="ghost" onClick={...}>← Previous</Button>
                }
            } @else {
                #html { <div></div> }
            }}
            @{if(props.next_id.size() > 0) {
                #html {
                    <Button variant="default" onClick={...}>Next →</Button>
                }
            } @else {
                #html { <div></div> }
            }}
        </Stack>
    }
}
```

## Gotchas

1. **No `if` without `else`**: Chemical requires else for every if block
2. **State only with `state` keyword**: `var` doesn't create reactive signals
3. **Loops use `while` not `for`**: `while(i < n) { ... i = i + 1 }`
4. **No inline if expressions**: Extract to variable: `var x = if(c) { a } else { b }`
5. **Vector access**: Use `.get_ptr(i)` not `.get(i)` for mutable access
6. **String comparison**: Use `.equals()` not `==`
7. **Pointer types**: `&string` vs `*string` — check function signatures
8. **Theme required**: Always call `page.inject_default_components_theme()` before using components
