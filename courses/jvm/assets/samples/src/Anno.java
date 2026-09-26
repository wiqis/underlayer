import java.lang.annotation.*;
@Retention(RetentionPolicy.RUNTIME)
@Target({ElementType.TYPE, ElementType.METHOD})
@interface Marker { String value() default "x"; int num() default 1; }
@Marker("hello")
public class Anno {
    @Marker(value="m", num=2) @Deprecated public void go() {}
}
