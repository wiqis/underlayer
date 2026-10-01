// underlayer_web — Route 1 of 3: the formats.
//
// The shape of this route is one question asked seven times.  ELF is first
// because it is the only course in the collection with no prerequisites and
// the one every other format course is written against; the three container
// formats come next in the order their differences are most instructive; then
// the two formats with no operating-system loader in them at all; then the
// format that does not travel as an executable at all.
using std::string
using std::vector

public namespace underlayer_web {

    public func route_formats() : PathRoute {
        var r = PathRoute::make()
        r.id = string("formats")
        r.name = string("Formats: what a binary is")
        r.tagline = string("One question, asked seven times.")
        r.blurb = string("Start with one container you can read end to end with nothing but xxd. Then read the others as answers to the same questions, because the differences are the evidence that these fields are answers and not laws. Finish with the two formats that are verified rather than loaded, and with the one that makes a loaded executable debuggable.")
        r.steps.push(mk_step(string("elf"), string("The only course here with no prerequisites, and the one the other six are written against. Nothing else in the collection declares it a dependency as often as it does.")))
        r.steps.push(mk_step(string("macho"), string("Mach-O answers the header, segment, symbol and relocation questions ELF just answered. Its load commands, __LINKEDIT and chained fixups are the clearest proof that these fields are one platform's answers rather than the answers.")))
        r.steps.push(mk_step(string("pe"), string("PE answers them a third time, with a DOS stub, sixteen data directories and an RVA model. Having read ELF and Mach-O, the DOS stub reads as an accident rather than a mystery.")))
        r.steps.push(mk_step(string("coff"), string("The object-file layer all three share: PE is built out of COFF, and so is the classic Mach-O object file. It sits after the two of them and before the formats that are only a container.")))
        r.steps.push(mk_step(string("jvm"), string("A format with no operating system in it. The class file is verified, not loaded, and after ELF, PE and Mach-O that trade is legible as a container giving up the loader's job to a verifier.")))
        r.steps.push(mk_step(string("wasm"), string("Almost every number in the file is one variable-width encoding, and the core specification deliberately does not define an object file. It is the format where the compiler/runtime boundary is being renegotiated in public.")))
        r.steps.push(mk_step(string("dwarf"), string("The format that travels beside an executable instead of being one, and the only reason a stack trace can name a line. Last because it is what you read once everything else is already in place.")))
        return r
    }

}