// Historical test entry point — NOT compiled.
// The suite is its own application (tests/chemical.mod, source "src") built without
// `--test`; its live entry point is tests/src/main.ch. Kept for reference only.
public func main(argc : int, argv : **char) : int {
    return test_runner(argc, argv)
}