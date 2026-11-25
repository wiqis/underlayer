// underlayer_web — #html components for the /courses index.
//
// WHY THE MARKUP IS SPLIT INTO COMPONENT FUNCTIONS.  `#html` blocks cannot be
// split (docs/implementation-gaps.md: an element opened in one block must be
// closed in the same block) and `@{}` statement blocks cannot lex at all.  So
// a loop inside one block is impossible.  What does work is calling a
// component function from inside a block -- `{render_x(data, page)}` -- which
// is how every repeated row on this page is produced, and it is how the
// collection's own html_cbi tests express it.  The alternative the rest of
// the codebase uses for dynamic lists is to render client-side from
// /api/courses; that was rejected here because /courses is the page a learner
// reaches when they cannot find anything, and a page that renders nothing
// without JavaScript is a bad page to be lost on.  Every row below is in the
// served HTML.
//
// NOTE the two calling conventions, both of which the compiler enforces and
// neither of which is obvious: inside a `#html` block a component takes `page`
// bare, because the macro has already made the reference (`&mut page` there is
// `&mut &mut HtmlPage` and is rejected); outside a block, in plain Chemical,
// it takes `&mut page`.
using std::string
using std::string_view
using std::vector

public namespace underlayer_web {

    // Kept as the one renderer for direct lesson links; a course page uses it
    // when it needs a flat list of lessons.  Values are RAW here -- the #html
    // macro escapes once, and pre-escaping produced literal &#39; on the page.
    public func render_concept_links(links : &vector<ConceptLink>, page : &mut HtmlPage) {
        var n : size_t = links.size()
        var i : size_t = 0
        while(i < n) {
            var link = links.at_ref(i)
            var tag = string()
            if(link.module_title.size() > 0) {
                tag = link.module_title.copy()
                tag.append_view(string_view(": "))
            }
            tag.append_string(&link.title)
            #html {
                <li class="concept-item"><a href={link.href}>{tag}</a></li>
            }
            i = i + 1
        }
    }

    // ONE card: title, the count a learner needs, and a single link into the
    // course.  The route essays and the expandable concept wall were removed:
    // on /courses they are a second information architecture competing with
    // the ordered /learning-path page.  The data attributes drive the local
    // search and difficulty filter; no request is made to filter the grid.
    public func render_catalog_card(card : &CatalogCard, page : &mut HtmlPage) {
        #html {
            <article class="course-card" data-search={card.search_text} data-difficulty={card.difficulty}>
                <h3><a href={card.href}>{card.title}</a></h3>
                <p class="course-desc">{card.description}</p>
                <p class="course-stats">
                    <span>{card.concepts} lessons</span>
                    <span>{card.minutes} min</span>
                    <span class="stat-diff">{card.difficulty}</span>
                </p>
            </article>
        }
    }

    // Every card, in one call.  This is the loop-inside-a-block the language
    // cannot write directly: the `#html` block above emits one balanced card,
    // this function emits the cards inside the grid.
    public func render_all_cards(cards : &vector<CatalogCard>, page : &mut HtmlPage) {
        var i : size_t = 0
        var n : size_t = cards.size()
        while(i < n) {
            render_catalog_card(cards.at_ref(i), page)
            i = i + 1
        }
    }

}
