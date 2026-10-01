// underlayer_web — The home page's Ctrl+K search modal.
//
// WHY IT MOVED OUT OF home_assets.ch AND WHY IT FETCHES.  It used to be a
// hardcoded array of 24 concept names and URLs, all of them ELF, hardcoded in
// 2016-era fashion next to the CSS.  It worked, and it was quietly wrong: the
// collection has 398 concepts, so the modal claimed to search concepts and
// could reach 6% of them.  It found nothing for `cmpxchg`, nothing for
// `satp`, and nothing for `relro` -- all three of which are in the course
// descriptions the modal was supposed to be finding.
//
// An index that lies about its own coverage is worse than no index, and the
// same discipline that produced tools/link_check.py applies here: the modal now
// calls GET /api/search/concepts, which is the same code path /search uses, so
// the two cannot disagree about what a query means.  The full page at /search
// is still the better surface -- it is server-rendered, shareable and works
// without JavaScript -- and the modal's hint now says so.
using std::string

public namespace underlayer_web {

    public func render_home_search_js(page : &mut HtmlPage) {
        #js {
            var searchTimer = null;
            function openSearch() {
                var m = document.getElementById("search-modal");
                if (m) { m.classList.add("open"); }
                var i = document.getElementById("search-input");
                if (i) { i.focus(); }
            }
            function closeSearch() {
                var m = document.getElementById("search-modal");
                if (m) { m.classList.remove("open"); }
                var i = document.getElementById("search-input");
                if (i) { i.value = ""; }
                var r = document.getElementById("search-results");
                if (r) { r.innerHTML = ""; }
            }
            function renderSearchResults(hits) {
                var box = document.getElementById("search-results");
                if (!box) return;
                box.innerHTML = "";
                if (hits.length === 0) {
                    box.innerHTML = '<div class="search-hint">Nothing in the collection matches that. Try a register name, a flag, a structure name.</div>';
                    return;
                }
                hits.forEach(function (hit) {
                    var a = document.createElement("a");
                    a.className = "search-result-item";
                    a.href = hit.url;
                    var title = document.createElement("span");
                    title.className = "search-result-title";
                    title.textContent = hit.title;
                    var where = document.createElement("span");
                    where.className = "search-result-course";
                    where.textContent = hit.course_title;
                    a.appendChild(title);
                    a.appendChild(where);
                    box.appendChild(a);
                });
                var more = document.createElement("a");
                more.className = "search-result-item search-result-more";
                more.href = "/search?q=" + encodeURIComponent(document.getElementById("search-input").value);
                more.textContent = "Open the full results page";
                box.appendChild(more);
            }
            function doSearch(q) {
                var trimmed = String(q || "").trim();
                if (trimmed.length < 2) {
                    var r0 = document.getElementById("search-results");
                    if (r0) { r0.innerHTML = ""; }
                    return;
                }
                if (searchTimer) { clearTimeout(searchTimer); }
                searchTimer = setTimeout(function () {
                    fetch("/api/search/concepts?q=" + encodeURIComponent(trimmed))
                        .then(function (resp) { return resp.json(); })
                        .then(function (data) { renderSearchResults(data.results || []); })
                        .catch(function () {
                            var box = document.getElementById("search-results");
                            if (box) { box.innerHTML = '<div class="search-hint">Search is unavailable right now. <a href="/courses">Browse the index</a> instead.</div>'; }
                        });
                }, 180);
            }
        }
    }

}