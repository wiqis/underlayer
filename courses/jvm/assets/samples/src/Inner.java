public class Inner {
    static class Nested { int x; }
    class Member { int y; }
    interface Iface { void go(); }
    enum E { A, B }
    Runnable r = new Runnable() { public void run() {} };
    void use() { class Local {} new Local(); }
}
