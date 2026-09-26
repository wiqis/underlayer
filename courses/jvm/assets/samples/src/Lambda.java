import java.util.function.*;
import java.util.*;
public class Lambda {
    Supplier<String> a = () -> "x";
    Function<Integer,Integer> b = n -> n + 1;
    BiFunction<Integer,Integer,Integer> c = (p, q) -> p * q;
    Runnable d = Lambda::hello;
    Supplier<List<String>> e = ArrayList::new;
    Predicate<String> f = String::isEmpty;
    static void hello() {}
    String concat(String a, String b) { return a + b; }
    void use() {
        Supplier<String> g = this::id0;
        System.out.println(a.get() + b.apply(1) + c.apply(2,3) + e.get() + f.test(""));
    }
    String id0() { return ""; }
}
class Anno2 { }
