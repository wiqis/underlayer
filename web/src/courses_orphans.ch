// underlayer_web — The courses no route claims, rendered with the reason.
//
// Printed rather than omitted.  An index that quietly drops a 69-concept
// course reads as a bug, and here it genuinely is one: `hat` is the only
// beginner course in the collection, has no dependencies and nothing depends
// on it, and belongs to none of the three technical routes.  Saying that is
// honest; pretending it was not in the collection is not.
//
// A COMPACT ROW, NOT A SECOND CARD.  The first version of this note rendered
// the orphan with the same card component as the catalogue, which put `hat` on
// the page twice -- once in the catalogue where it already was, and once here.
// A course appearing twice in its own index is the kind of small wrongness a
// reader notices and cannot un-notice.  The catalogue is the one place a
// course appears; this note says where it sits in the collection and links to
// it.
using std::string
using std::string_view
using std::vector
using underlayer_models::Course

public namespace underlayer_web {

    public func build_orphan_cards(courses : &vector<Course>, claimed : &vector<string>) : vector<CatalogCard> {
        var orphans = vector<CatalogCard>()
        var i : size_t = 0
        while(i < courses.size()) {
            var c = courses.get_ptr(i)
            var cid = c.id.copy()
            if(!list_has(claimed, &cid)) {
                var card = CatalogCard::make()
                var href = string("/courses/")
                href.append_string(&cid)
                var href_esc = underlayer_core::html_escape(&href)
                card.href = href_esc
                var title = c.title.copy()
                var title_esc = underlayer_core::html_escape(&title)
                card.title = title_esc
                var desc = c.description.copy()
                var desc_esc = underlayer_core::html_escape(&desc)
                card.description = desc_esc
                var diff = c.difficulty.copy()
                var diff_esc = underlayer_core::html_escape(&diff)
                card.difficulty = diff_esc
                var imp = c.importance.copy()
                var imp_esc = underlayer_core::html_escape(&imp)
                card.importance = imp_esc
                card.modules = c.modules.size() as int
                card.concepts = c.concepts.size() as int
                card.minutes = minutes_of(c)
                var links = concept_links_for(c)
                card.concept_links = links
                orphans.push(card)
            }
            i = i + 1
        }
        return orphans
    }

    public func render_orphan_note(courses : &vector<Course>, claimed : &vector<string>, course_count : int, page : &mut HtmlPage) {
        var orphans = build_orphan_cards(courses, claimed)
        var n = orphans.size() as int
        var note = string()
        var ns = underlayer_core::int_to_string(n as i64)
        note.append_string(&ns)
        note.append_view(string_view(" of the "))
        var cc = underlayer_core::int_to_string(course_count as i64)
        note.append_string(&cc)
        note.append_view(string_view(" courses sits outside all three routes: it has no prerequisites, nothing declares it a dependency, and it is not part of the linking chain or either architecture half. It is listed here rather than left out, because an index that silently drops "))
        var dropped = 0
        var oi : size_t = 0
        while(oi < orphans.size()) {
            var oc = orphans.get_ptr(oi)
            dropped = dropped + oc.concepts
            oi = oi + 1
        }
        var ds = underlayer_core::int_to_string(dropped as i64)
        note.append_string(&ds)
        note.append_view(string_view(" concepts reads as a bug — and this one is. Its full card is in the catalogue below."))
        var note_esc = underlayer_core::html_escape(&note)
        #html {
            <div class="orphan-note">
                <h3>Outside the three routes</h3>
                <p>{note_esc}</p>
                {render_orphan_rows(&orphans, page)}
            </div>
        }
    }

    public func render_orphan_rows(orphans : &vector<CatalogCard>, page : &mut HtmlPage) {
        var i : size_t = 0
        while(i < orphans.size()) {
            var card = orphans.get_ptr(i)
            #html {
                <div class="orphan-row">
                    <a href={card.href}>{card.title}</a>
                    <span>{card.modules} modules</span>
                    <span>{card.concepts} concepts</span>
                    <span>{card.minutes} min</span>
                    <span class="stat-diff">{card.difficulty}</span>
                </div>
            }
            i = i + 1
        }
    }

}