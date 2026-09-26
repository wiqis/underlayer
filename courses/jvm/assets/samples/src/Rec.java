public record Rec(int x, String name, long[] data) {
    public Rec { if (x < 0) throw new IllegalArgumentException(); }
    static final int ORIGIN = 0;
}
