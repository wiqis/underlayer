struct Point { int x, y; };
int  sum_table(int idx);
int  walk(struct Point *p);
struct Point make_point(int x, int y);
int main(void) {
    struct Point p = make_point(3, 4);
    return sum_table(1) + walk(&p) + p.x;
}
