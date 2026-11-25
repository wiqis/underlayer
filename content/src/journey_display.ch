// underlayer_content — ONE labelled home for the display/accessibility controls.
//
// 398 lesson files currently carry seven accessibility buttons and four
// reading dropdowns above the content. Rewriting them is out of the question
// (and would break the "never hand-edit lessons" rule), so this helper MOVES
// the existing blocks into one labelled "Display & accessibility" disclosure
// in the journey shell at boot, and puts them back exactly where they came
// from in Deep dive. Moving DOM nodes keeps their listeners and their inline
// onchange handlers; no control is recreated and no behaviour is re-authored.
//
// While the journey is active the shared CSS in journey_shell.ch hides the
// original positions; this helper is what makes the controls reachable in the
// one place rather than deleting them. With scripting off the shell is hidden
// and every original control stays visible — the backend-optional fallback.
using std::string

public namespace underlayer_content {

    public func render_journey_display_js(page : &mut HtmlPage) {
        #js {
            window.__ulJourneyDisplay = function(restore) {
                var slot = document.getElementById('ul-journey-display-slot');
                var lesson = document.querySelector('.lesson');
                if(!slot || !lesson) { return; }
                var selectors = ['.a11y-controls', '.cb-controls', '.reading-controls'];
                var i = 0;
                while(i < selectors.length) {
                    var nodes = document.querySelectorAll(selectors[i]);
                    var j = 0;
                    while(j < nodes.length) {
                        var el = nodes[j];
                        if(restore) {
                            var homeId = el.getAttribute('data-jq-display-home');
                            if(homeId && el.parentNode === slot) {
                                var home = document.getElementById(homeId);
                                if(home) { home.appendChild(el); }
                                else { lesson.appendChild(el); }
                                el.removeAttribute('data-jq-display-home');
                            }
                        } else {
                            if(el.parentNode !== slot) {
                                var parent = el.parentNode;
                                var parentId = parent.getAttribute('id');
                                if(!parentId) {
                                    var seq = window.__ulJqHomeSeq || 0;
                                    window.__ulJqHomeSeq = seq + 1;
                                    parentId = 'jq-display-home-' + window.__ulJqHomeSeq;
                                    parent.setAttribute('id', parentId);
                                }
                                el.setAttribute('data-jq-display-home', parentId);
                                slot.appendChild(el);
                            }
                        }
                        j = j + 1;
                    }
                    i = i + 1;
                }
            };
        }
    }
}
