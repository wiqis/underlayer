// Underlayer test entry point — calls the test runner.
// Only compiled when `--test` is passed (see chemical.mod: source "tests" if test).
public func main(argc : int, argv : **char) : int {
    return test_runner(argc, argv)
}