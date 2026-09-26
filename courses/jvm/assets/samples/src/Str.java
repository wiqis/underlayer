public class Str {
    String plain   = "hello";
    String nul     = "a\0b";                 // an embedded NUL, octal escape
    String emoji   = "hi \uD83C\uDF89";      // SUPPLEMENTARY: a surrogate pair
    String high2   = "\u00FF";                // max 2-byte BMP
    String high3   = "\uFFFF";                // max 3-byte BMP
    char   bmp     = '\uFFFF';           // a char holds ONE UTF-16 code unit
    String mixed   = "a\0b\uD83C\uDF89\u00FF\uFFFF";
}
