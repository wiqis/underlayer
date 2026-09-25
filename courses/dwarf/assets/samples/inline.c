struct Vec { double x, y, z; };
static double dot(struct Vec a, struct Vec b) {
    return a.x * b.x + a.y * b.y + a.z * b.z;
}
double magnitude2(struct Vec v) {
    return dot(v, v);
}
double work(struct Vec a, struct Vec b) {
    return dot(a, b) + dot(b, a) + dot(a, a);
}
int main(void) { struct Vec a = {1,2,3}, b = {4,5,6}; return (int)work(a,b); }
