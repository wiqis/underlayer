// Safe static-page writer shared by every course's build entry point.
// The pre-safety fs::mkdir / fs::write_text_file calls no longer exist; the
// current fs API takes a path::Path and bytes, and returns a Result.
public namespace course_writer {

    public func ensure_output() : bool {
        var dir = path::Path.new(std::str.make_view(std::string_view("output")))
        var made = fs::create_dir_all(&dir)
        if(made is std::Result.Err) {
            println(`course_writer: could not create output directory`)
            return false
        }
        return true
    }

    public func write_page(filename : std::string_view, html : &std::string) : bool {
        var file = path::Path.new(std::str.make_view(filename))
        var written = fs::write(&file, html.as_bytes())
        if(written is std::Result.Err) {
            println(`course_writer: could not write page`)
            return false
        }
        return true
    }
}
