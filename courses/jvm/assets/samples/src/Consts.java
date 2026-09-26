public class Consts {
    // every constant-pool tag in one class
    static final int    I32   = 0x7f4a2c19;         // Integer
    static final long   I64   = 0x0123456789abcdefL; // Long     -> 2 slots
    static final float  F32   = 3.5f;               // Float
    static final double F64   = -2.718281828459045; // Double   -> 2 slots
    static final String S     = "hello \u00e9\u4e16"; // String
    static final int    NAN   = 0x7f800000;         // another Integer
    static final long   MIN   = Long.MIN_VALUE;     // another Long -> 2 slots
    static final double NAN2  = Double.NaN;         // another Double -> 2 slots
    int  arr[] = new int[4];
    Consts self;
    void takes(Object o) {}
}
