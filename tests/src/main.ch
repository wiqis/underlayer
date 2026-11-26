// tests/src/main.ch — the @test suite entry point.
//
// The suite is its own application (`tests/chemical.mod`) built WITHOUT
// `--test`, so it needs its own `main` inside the manifest's `source "src"`
// root. `@override` lets it coexist with any library's own test `main`.
@override
public func main(argc : int, argv : **char) : int {
    return test_runner(argc, argv)
}
