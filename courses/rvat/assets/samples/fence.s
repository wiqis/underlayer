// `fence` and its four fields, hand-written.  Every fence the assembler will
// accept at fm = 0000, one line each, and then the two non-fence words that
// share opcode 0x0f: `fence.tso` at fm = 1000 and `fence.i` at funct3 = 1.
//
// THE PAIRS ARE DELIBERATE.  Every line below appears twice in different
// orders and with the operands swapped, because the whole point of the
// instruction is that `pred` and `succ` are TWO FOUR-BIT SETS and a reader who
// has only seen `fence rw, rw` has seen one of sixteen shapes.  `fence r, w`
// beside `fence w, r` is the cheapest possible demonstration that the two
// halves are not a symmetric pair written twice.

        // ---- the all-but-self set, spelled and bare -------------------
        fence
        fence iorw, iorw

        // ---- the load/store half, as a SET ---------------------------
        fence r, r
        fence w, w
        fence rw, rw
        fence r, rw
        fence rw, r
        fence w, r
        fence r, w
        fence w, rw
        fence rw, w
        fence iorw, r
        fence r, iorw
        fence iorw, w
        fence w, iorw

        // ---- the I/O half, which is a DIFFERENT AXIS and not a
        //      superset of anything above
        fence i, i
        fence o, o
        fence io, io
        fence i, io
        fence io, i
        fence io, r
        fence r, io
        fence io, rw
        fence rw, io
        fence i, rw
        fence rw, o
        fence o, rw

        // ---- every two-letter combination, so the SET of accepted
        //      SPELLINGS is a measurement and not a claim
        fence ior, io
        fence iow, io
        fence irw, io
        fence orw, io
        fence ir, io
        fence iw, io
        fence or, io
        fence ow, io

        // ---- the two words that share the opcode and are NOT fences --
        //      fm = 1000 is one instruction of its own, and funct3 = 1 is
        //      a different EXTENSION, which is the reason the inherited
        //      decoder has to put the ordering fence ABOVE the SYSTEM
        //      model and not the other way round.
        fence.tso
        fence.tso
        fence.i
        fence.i

        ret