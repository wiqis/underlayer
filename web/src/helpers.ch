// underlayer_web — Shared helpers.
// Public so other files in the module can use them.
using std::string
using std::string_view

public namespace underlayer_web {

    public func send_page(res : *mut http::ResponseWriter, page : *HtmlPage) {
        var ct = std::string_view("text/html; charset=utf-8")
        res.set_header_view(std::string_view("Content-Type"), &ct)
        var html = page.toString()
        var hv = html.to_view()
        res.write_view(&hv)
    }

    public func send_json_str(res : *mut http::ResponseWriter, body : *string) {
        var ct = std::string_view("application/json")
        res.set_header_view(std::string_view("Content-Type"), &ct)
        var bv = body.to_view()
        res.write_view(&bv)
    }

    public func send_error(res : *mut http::ResponseWriter, status : uint, msg : &string) {
        res.status = status
        var ct = std::string_view("application/json")
        res.set_header_view(std::string_view("Content-Type"), &ct)
        var body = std::string("{\"error\":\"")
        body.append_string(msg)
        body.append_view("\"}")
        var bv = body.to_view()
        res.write_view(&bv)
    }

    public func sv_to_string(sv : *string_view) : string {
        var out = std::string()
        var i : size_t = 0
        while(i < sv.size()) { out.append(sv.get(i)); i = i + 1 }
        return out
    }

    public func render_concept(concept_id : *string) : string {
        var cid = concept_id.copy()
        var bytes_id = std::string("bytes")
        var binrep_id = std::string("binary-representation")
        var filelayout_id = std::string("file-layout")
        var elfident_id = std::string("elf-identification")
        var elfheader_id = std::string("elf-header-fields")
        var entrypoint_id = std::string("entry-point")
        var progheader_id = std::string("program-header-table")
        var segtype_id = std::string("segment-types")
        var memmap_id = std::string("memory-mapping")
        var sectheader_id = std::string("section-header-table")
        var commonsec_id = std::string("common-sections")
        var secvsseg_id = std::string("section-vs-segment")

        if(cid.equals(&bytes_id)) { return underlayer_content::render_bytes() }
        if(cid.equals(&binrep_id)) { return underlayer_content::render_binary_representation() }
        if(cid.equals(&filelayout_id)) { return underlayer_content::render_file_layout() }
        if(cid.equals(&elfident_id)) { return underlayer_content::render_elf_identification() }
        if(cid.equals(&elfheader_id)) { return underlayer_content::render_elf_header_fields() }
        if(cid.equals(&entrypoint_id)) { return underlayer_content::render_entry_point() }
        if(cid.equals(&progheader_id)) { return underlayer_content::render_program_header_table() }
        if(cid.equals(&segtype_id)) { return underlayer_content::render_segment_types() }
        if(cid.equals(&memmap_id)) { return underlayer_content::render_memory_mapping() }
        if(cid.equals(&sectheader_id)) { return underlayer_content::render_section_header_table() }
        if(cid.equals(&commonsec_id)) { return underlayer_content::render_common_sections() }
        if(cid.equals(&secvsseg_id)) { return underlayer_content::render_section_vs_segment() }
        return string()
    }

}
