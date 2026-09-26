public abstract sealed interface Sealed permits Sealed.A, Sealed.B {
    record A(int x) implements Sealed {}
    record B(String s) implements Sealed {}
}
