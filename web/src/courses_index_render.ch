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
// it takes `&mut page`.  A `*CatalogCard` arrives from `vector::get_ptr`, so
// the component's parameter is a pointer, not a reference.
using std::string
using std::string_view
using std::vector

public namespace underlayer_web {

    // The concept list inside a card's <details>.  Every concept links
    // straight to its lesson, so the index is a way into a lesson rather than
    // a second place to click through.
    public func render_concept_links(links : &vector<ConceptLink>, page : &mut HtmlPage) {
        var n : size_t = links.size()
        var i : size_t = 0
        while(i < n) {
            var link = links.get_ptr(i)
            var tag = string()
            if(link.module_title.size() > 0) {
                tag = link.module_title.copy()
                tag.append_view(string_view(": "))
            }
            tag.append_string(&link.title)
            var tag_esc = underlayer_core::html_escape(&tag)
            #html {
                <li class="concept-item"><a href={link.href}>{tag_esc}</a></li>
            }
            i = i + 1
        }
    }

    // One course card.  Balanced and self-contained so a plain Chemical while
    // loop can emit one per course.
    public func render_catalog_card(card : *CatalogCard, page : &mut HtmlPage) {
        #html {
            <article class="course-card">
                <div class="course-badge">{card.modules} modules</div>
                <h3><a href={card.href}>{card.title}</a></h3>
                <p class="course-desc">{card.description}</p>
                <div class="course-stats">
                    <span>{card.concepts} concepts</span>
                    <span>{card.minutes} min</span>
                    <span class="stat-diff">{card.difficulty}</span>
                    <span class="stat-imp">{card.importance}</span>
                </div>
                @if(card.place.step > 0) {
                    <p class="route-line"><span class="route-name">{card.place.route_name}</span> &middot; step {card.place.step}</p>
                    <p class="route-why">{card.place.reason}</p>
                } @else {
                    <p class="route-line route-none">Outside the three routes &mdash; see the note below the routes.</p>
                }
                <details class="concepts">
                    <summary>{card.concepts} concepts</summary>
                    <ul class="concept-list">
                        {render_concept_links(&card.concept_links, page)}
                    </ul>
                </details>
            </article>
        }
    }

    // Every card, in one call.  This is the loop-inside-a-block the language
    // cannot write directly: the `#html` block above emits a grid, this
    // function emits the balanced cards inside it, and the grid is a grid
    // because its items are children of it in the served HTML.
    public func render_all_cards(cards : &vector<CatalogCard>, page : &mut HtmlPage) {
        var i : size_t = 0
        var n : size_t = cards.size()
        while(i < n) {
            render_catalog_card(cards.get_ptr(i), page)
            i = i + 1
        }
    }

}