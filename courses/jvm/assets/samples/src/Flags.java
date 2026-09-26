public abstract class Flags implements Runnable, Comparable<Flags> {
    public static final int PUB_STATIC_FINAL = 1;
    private volatile transient long priv;
    protected int prot;
    int packagePrivate;
    public abstract void abstractMethod();
    public final synchronized native void nativeMethod();
    protected native void nativeProtected();
    public int compareTo(Flags o) { return 0; }
    public void run() {}
    public static strictfp void strict() {}
}
