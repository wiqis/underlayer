import java.util.*;
public class Gen<T extends Comparable<T> & Cloneable, V> {
    Map<String, List<? extends Number>> m;
    T t; V v;
    public <R> R conv(T in, java.util.function.Function<T,R> f) { return f.apply(in); }
    List<Map.Entry<String,int[]>> deep;
}
