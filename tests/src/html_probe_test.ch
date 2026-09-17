// TEMPORARY probe — isolates @{ } statement-block parsing inside #html.
// Delete after the landing implementation lands.
using std::string
using std::string_view
using std::vector

namespace html_probe {

    func emit_li(page : *mut HtmlPage, label : &string) {
        #html {
            <li class="p">{label}</li>
        }
    }

    // Variant A: @{ single while } inside an element, helper emits the li.
    public func render_variant_a() : string {
        var page = HtmlPage()
        page.defaultPrepare()
        var items = vector<string>()
        items.push(string("a1"))
        items.push(string("a2"))
        var i : size_t = 0
        #html {
            <div class="va">
                <ul>
                @{
                    while(i < items.size()) {
                        var it_ptr = items.get_ptr(i)
                        var it = it_ptr.copy()
                        emit_li(page, &it)
                        i = i + 1
                    }
                }
                </ul>
            </div>
        }
        return page.toString()
    }

}

@test
public func test_html_probe_variant_a(env : &mut TestEnv) {
    var html = html_probe::render_variant_a()
    if(html.find(string_view("a1")) == std::NPOS) { env.error("variant a missing a1") }
    if(html.find(string_view("a2")) == std::NPOS) { env.error("variant a missing a2") }
}
