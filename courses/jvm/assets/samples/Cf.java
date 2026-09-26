// A third, independent reader for the JVM class file format.
//
// The other two readers are `javap -v` and this course's own Python decoder.
// This one is deliberately different from both: it uses `java.lang.classfile`,
// the JDK's own standard API for parsing class files, added in Java 22. It is
// the JDK parsing class files through a supported interface rather than
// through a disassembler, so a bug in a third-party reader cannot hide here.
//
// It prints a normalised, line-oriented summary so the crosscheck can diff it
// against the other two. It is a READER, not a validator: it will happily print
// a file the JVM would reject, exactly like the Python decoder.
//
//   javac -d . Cf.java
//   java -cp . Cf Foo.class
//
// One note on the API, because it cost time and the course should not repeat
// the mistake: the entry points are `fieldName()`/`fieldType()` and
// `methodName()`/`methodType()`, NOT `descriptorString()`. And a class entry's
// name comes from `asInternalName()`, not `displayName()`. Both were wrong in
// the first draft of this file.

import java.lang.classfile.ClassFile;
import java.nio.file.Path;

public class Cf {
    public static void main(String[] args) throws Exception {
        for (String a : args) {
            var cf = ClassFile.of().parse(Path.of(a));
            System.out.println("file: " + a);
            System.out.println("  minor " + cf.minorVersion());
            System.out.println("  major " + cf.majorVersion());
            System.out.println("  thisClass "
                    + cf.thisClass().asInternalName().replace('/', '.'));
            var sup = cf.superclass();
            System.out.println("  superClass " + (sup.isPresent()
                    ? sup.get().asInternalName().replace('/', '.') : "(none)"));
            System.out.println("  interfaces " + cf.interfaces().size());
            System.out.println("  fields " + cf.fields().size());
            for (var f : cf.fields()) {
                System.out.println("    field " + f.fieldName().stringValue()
                        + " " + f.fieldType().stringValue());
            }
            System.out.println("  methods " + cf.methods().size());
            for (var m : cf.methods()) {
                System.out.println("    method " + m.methodName().stringValue()
                        + " " + m.methodType().stringValue());
            }
            System.out.println("  attributes " + cf.attributes().size());
            for (var at : cf.attributes()) {
                System.out.println("    attr " + at.attributeName().stringValue());
            }

            // The constant pool, walked through the API. `ConstantPool` lives
            // in the `constantpool` subpackage and is Iterable, so a for-each
            // over it is the API's own view of the slot layout. If Long and
            // Double really do consume two indices then the iteration has to
            // account for it -- and this is where that shows up, as a null in
            // the middle of the sequence. Counting those nulls independently
            // confirms the holes are real and not a quirk of the Python
            // decoder.
            //
            // Two API names cost time here and are worth recording: the pool
            // type is java.lang.classfile.constantpool.ConstantPool (not
            // java.lang.classfile.ConstantPool), and it is iterated directly
            // rather than through an entries() method.
            var cp = cf.constantPool();
            int usable = 0;
            int holes = 0;
            StringBuilder holeIdx = new StringBuilder();
            StringBuilder tags = new StringBuilder();
            for (var e : cf.constantPool()) {
                if (e == null) { holes++; continue; }
                usable++;
                if (tags.length() < 3000) tags.append(' ').append(e.tag());
            }
            // size() is the RAW constant_pool_count, holes included -- 52 for a
            // pool with 47 usable entries. The iteration above yields only the
            // usable ones, so iteration length and size() disagree, and that
            // disagreement IS the Long/Double slot rule seen from the JDK.
            System.out.println("  cpSize " + cp.size());
            System.out.println("  cpUsable " + usable);

            // Now probe the holes directly. entryByIndex() on the second half of
            // a Long or a Double does not return null and does not return a
            // wrong entry: it THROWS ConstantPoolException. So the JDK treats an
            // unusable index as a hard error, which is a stronger statement
            // than "there is a gap you had better notice".
            for (int i = 1; i < cp.size(); i++) {
                try {
                    cp.entryByIndex(i);
                } catch (java.lang.classfile.constantpool.ConstantPoolException e) {
                    holes++;
                    holeIdx.append(' ').append(i);
                }
            }
            System.out.println("  cpHoles " + holes);
            System.out.println("  cpHoleIdx" + holeIdx);
            System.out.println("  cpTags" + tags);
        }
    }
}
