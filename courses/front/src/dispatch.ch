// Served-path dispatcher.  The web layer resolves concept ids GLOBALLY, so
// this file exists to make the coordinator's hook two lines: import the course
// module in the root chemical.mod, then call render_front_concept from
// underlayer_web::render_concept before the generic ELF table.  It is authored
// here because this work package owns courses/front/** and not web/src/**.
public namespace front_pages {

using std::string

public func render_front_concept(concept_id : &string) : string {
    var id = concept_id.copy()
    var lexer_id = std::string("fe-lexer")
    var parser_id = std::string("fe-recursive-descent")
    var ast_id = std::string("fe-ast")

    if(id.equals(&lexer_id)) { return render_fe_lexer() }
    if(id.equals(&parser_id)) { return render_fe_recursive_descent() }
    if(id.equals(&ast_id)) { return render_fe_ast() }
    return string()
}

}
