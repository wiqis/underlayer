// underlayer_web — Home page handler.
using std::string
using std::string_view

public namespace underlayer_web {

    public func handle_home(req : &http::Request, res : *mut http::ResponseWriter) {
        var page = HtmlPage()
        page.defaultPrepare()
        var title = std::string_view("Underlayer - Learn Things Deeply")
        page.appendTitle(&title)

        #html {
            <div style="max-width: 800px; margin: 0 auto; padding: 2rem; font-family: system-ui, sans-serif;">
                <h1 style="font-size: 2rem; margin-bottom: 0.5rem;">Underlayer</h1>
                <p style="font-size: 1.1rem; color: #4b5563; margin-bottom: 2rem;">Learn Things Deeply.</p>
                <div style="padding: 1.5rem; border: 1px solid #e5e7eb; border-radius: 8px;">
                    <h2>ELF — Executable and Linkable Format</h2>
                    <p style="color: #6b7280;">A deep dive into the ELF binary format.</p>
                    <a href="/courses/elf" style="color: #3b82f6;">Start Learning</a>
                </div>
            </div>
        }

        #css {
            body { font-family: system-ui, sans-serif; line-height: 1.6; }
            a { color: #3b82f6; text-decoration: none; }
            a:hover { text-decoration: underline; }
        }

        send_page(res, &raw page)
    }

}
