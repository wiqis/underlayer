// HAT course — shared lesson CSS + JS.
//
// Thin wrappers over the shared 8-unit lesson assets so existing HAT concept
// files keep their names. Behaviour lives in lesson_assets.ch.
public namespace underlayer_content {

    public func render_hat_lesson_css(page : &mut HtmlPage) {
        render_lesson_css(page)
    }

    public func render_hat_lesson_js(page : &mut HtmlPage) {
        render_lesson_js(page)
    }

}
