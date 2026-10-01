// underlayer_web — Route 2 of 3: the mission's chain, in dependency order.
//
// `docs/course-mission.md` states the chain the whole collection exists to
// serve, and names the seven linking courses in this order.  The six neutral
// courses follow them, and they follow rather than precede for a stated
// reason: `isa` declares `obj` and `sec` as prerequisites, so a course that
// teaches what the bytes in .text are cannot honestly come before the courses
// that explain what produced them and what the loader will do to them.  That
// is not the order a syllabus would choose.  It is the order the declared
// prerequisites admit, and the verifier in routes_verify.ch checks it.
using std::string
using std::vector

public namespace underlayer_web {

    public func route_link() : PathRoute {
        var r = PathRoute::make()
        r.id = string("link")
        r.name = string("The link: IR to a running process")
        r.tagline = string("The mission's own chain, in the order the prerequisites allow.")
        r.blurb = string("This is the path the collection exists to serve. Object files, symbols, relocations, linking, the executable, the loader -- and then what the CPU and the memory hierarchy actually do with the result. Every step's declared prerequisites have already been read when you reach it; the page prints the count that says so.")
        r.steps.push(mk_step(string("obj"), string("The artefact every compiler emits and no programmer ever sees. It compares ELF, COFF and Mach-O object files side by side, which is why Route 1 comes first.")))
        r.steps.push(mk_step(string("sym"), string("The linker's central data structure, and the one both the static and the dynamic linker need. It is here rather than after relocations because a relocation's whole job is patching a reference to a symbol.")))
        r.steps.push(mk_step(string("reloc"), string("Why one relocation type is not enough -- absolute, PC-relative, GOT-relative, the addend and the pairing rules -- and what position independence actually costs. Needs both the file and the name, so it follows both.")))
        r.steps.push(mk_step(string("link"), string("The static linker's stages, now that it is known what it resolves and how. Linker scripts, archive selection and LTO only make sense once the stages are named.")))
        r.steps.push(mk_step(string("dyn"), string("PLT, GOT, lazy binding, symbol versioning and TLS: the same symbol table and the same relocations, resolved at run time instead of link time.")))
        r.steps.push(mk_step(string("img"), string("The loader. auxv, the initial stack, address-space layout, relocation at load, initialisers. The link has produced a file; this is what turns it into a process.")))
        r.steps.push(mk_step(string("sec"), string("Hardening flags, once you know which bytes are code, which are relocatable and which the loader decides. RELRO, W^X and CET read as changes to specific fields rather than as switches.")))
        r.steps.push(mk_step(string("isa"), string("What the bytes inside .text are: registers, flags, addressing modes and decoding, with all three instruction sets contrasted in one place. It declares obj and sec, which is exactly why it sits here and not earlier.")))
        r.steps.push(mk_step(string("exe"), string("How the CPU actually executes them: the pipeline, speculation, branch prediction, store buffers. Declares isa, sec and img, and all three are now behind you.")))
        r.steps.push(mk_step(string("mem"), string("What happens between a load and its value: caches and associativity, TLBs, stores, and why a chase and a sweep measure different things. Declares isa and exe.")))
        r.steps.push(mk_step(string("priv"), string("Exceptions, privilege levels and mode changes -- the boundary between asking for something and being refused, and the three ways in. Declares isa, exe, img and sec.")))
        r.steps.push(mk_step(string("smp"), string("Multiprocessor: true and false sharing, the cost of a lock prefix with nothing to lock against, NUMA. Declares mem, exe, isa and priv, so it closes the neutral core.")))
        r.steps.push(mk_step(string("simd"), string("Vectors last of the neutral courses because its costs are the memory hierarchy's costs: the same 4-wide loop wins on L1-resident data and stops winning at 24 MiB, with the lane count unchanged between the two numbers.")))
        return r
    }

}