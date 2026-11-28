// E6 paid course — concept 1: the first sixteen bytes.
// Every value below is read from assets/samples/readelf_h.txt.
public namespace underlayer_content {

using std::string
using std::string_view

public func render_bin_magic() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The First Sixteen Bytes — Underlayer")
    page.appendTitle(&title)
    render_lesson_nav(&mut page)
    render_lesson_css(&mut page)

    #html {
        <div class="lesson binread-lesson">
            <a href="/courses/binread" class="back-link">Back to course</a>
            <h1>The First Sixteen Bytes</h1>
            <div class="lesson-meta">12 min &middot; Module 1: First Look &middot; Beginner</div>

            <div class="unit unit-why" data-remember="The first sixteen bytes tell you class, byte order, version and ABI before any other field is read.">
                <h2>Why This Matters</h2>
                <p>You are handed a file with no extension and no tools you trust. Before you can read a single offset you have to answer four questions: is it ELF at all, is it 32- or 64-bit, which way are its numbers written, and which ABI's rules apply? All four answers are in the first sixteen bytes.</p>
                <p>The specimen for this course is a real x86-64 ELF copied byte-for-byte from the verified corpus. Its identification bytes are not invented: <code>readelf -h</code> prints them as <code>7f 45 4c 46 02 01 01 00 00 00 00 00 00 00 00 00</code>.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>The first sixteen bytes are <code>e_ident</code>, an array of fixed positions. Each position has one job, and the positions do not move between architectures:</p>
                <div class="hex-dump"><pre>offset  bytes          meaning                specimen
  0     7f 45 4c 46    magic: .ELF             present
  4     02             EI_CLASS               ELF64
  5     01             EI_DATA                little endian
  6     01             EI_VERSION             1 (current)
  7     00             EI_OSABI               UNIX - System V
  8     00             EI_ABIVERSION          0
  9-15  zeros          padding</pre></div>
                <p>Read the four magic bytes first: <code>7f</code> is not printable ASCII, followed by <code>E</code>, <code>L</code>, <code>F</code> (<code>45 4c 46</code>). If those four bytes are absent, none of the rest of this course applies to that file.</p>
            </div>

            <div class="unit unit-reality">
                <h2>Measured, in the File</h2>
                <p>The included evidence records the whole identification line for the specimen:</p>
                <div class="hex-dump"><pre>$ readelf -h types_O0
  Magic:   7f 45 4c 46 02 01 01 00 00 00 00 00 00 00 00 00
  Class:                             ELF64
  Data:                              2's complement, little endian
  Version:                           1 (current)
  OS/ABI:                            UNIX - System V
  ABI Version:                       0</pre></div>
                <p>Byte 4 being <code>02</code> is what makes the header 64 bytes and the program-header entries 56 bytes. Byte 5 being <code>01</code> is why the multi-byte fields that follow are read low byte first. Get either of these wrong and every later number is garbage even though the file is intact.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Worked Read</h2>
                <p>Suppose another file begins <code>7f 45 4c 46 01 02 01 00</code>. The magic still passes. Byte 4 is <code>01</code>, so it is ELF32, not ELF64. Byte 5 is <code>02</code>, so its integers are big-endian. Its header layout is a different structure with different field widths — the identification bytes told you that before you read any of it.</p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>The <a href="/courses/elf/lessons/elf-identification">ELF identification concept</a> covers the same array as part of the format reference. This course uses it as the first triage step: decide which layout you are looking at, then reach for the right table. In <a href="/courses/binread/lessons/bin-header">the next step</a> those class and order facts decide how to decode the header.</p>
            </div>

            <div class="unit unit-interact">
                <h2>See It</h2>
                <p>Open <code>assets/samples/readelf_h.txt</code> beside the hex of <code>types_O0</code>. Cover everything after byte 15 and write down the four answers before uncovering the labelled <code>readelf</code> output. The point is not to memorise the bytes; it is to trust a position-based read.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Take any other ELF in the specimen bundle, such as <code>demo_i386_elf.o</code>, and compare only byte 4 and byte 5 with the values above. State out loud which class and byte order it uses before looking at any other field.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>In the specimen's identification bytes, what does byte 4 equal and what does it tell you?</p>
                <div class="quiz" id="quiz-bin-magic-i1" aria-label="Check your understanding">
                    <button class="quiz-option" data-correct="false" data-explain="Byte 5 is 01, which is the little-endian data encoding. Byte 4 is the class." onclick="checkQuiz('quiz-bin-magic-i1', this)" aria-label="Option: 01, little-endian">01, little-endian</button>
                    <button class="quiz-option" data-correct="true" data-explain="02 at offset 4 is EI_CLASS=ELF64, which is why the specimen uses a 64-byte header." onclick="checkQuiz('quiz-bin-magic-i1', this)" aria-label="Option: 02, ELF64">02, ELF64</button>
                    <button class="quiz-option" data-correct="false" data-explain="00 at offset 7 is EI_OSABI=System V, not the class." onclick="checkQuiz('quiz-bin-magic-i1', this)" aria-label="Option: 00, System V">00, System V</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>
        </div>
    }

    render_lesson_js(&mut page)
    return page.toString()
}
}
