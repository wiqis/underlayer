public class Shapes {
    int tableswitch(int x) {
        switch (x) { case 0: return 1; case 1: return 2; case 2: return 3;
                     case 3: return 4; case 4: return 5; default: return -1; }
    }
    int lookupswitch(int x) {
        switch (x) { case 1: return 10; case 100: return 20; case 10000: return 30;
                     default: return -1; }
    }
    int wide(int x) { int a=0,b=0,c=0,d=0,e=0,f=0,g=0,h=0,i=0,j=0,k=0,l=0;
                     return a+b+c+d+e+f+g+h+i+j+k+l+x; }
    int trycatch(int x) {
        try { return 100/x; }
        catch (ArithmeticException e) { return -1; }
        catch (RuntimeException e) { return -2; }
        finally { x++; }
    }
}
