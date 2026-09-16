// Content Validator — entry point.
// Validates a course directory and prints a pass/fail report.
using std::string
using std::string_view
using std::vector

public func main(argc : int, argv : **char) : int {
    if(argc < 2) {
        printf("Usage: content_validator <course_dir>\n")
        printf("Example: content_validator courses/elf\n")
        return 1
    }

    // Build course path from argv[1]
    var course_dir = string()
    var i : int = 0
    var arg = *(argv + 1)
    while(arg[i] != 0) {
        course_dir.append(arg[i] as char)
        i = i + 1
    }

    printf("Validating course: %s\n", course_dir.data())
    printf("---\n")

    var results = content_validator::validate_course(&course_dir)
    var has_failures = content_validator::print_report(&results)

    if(has_failures) {
        return 1
    }
    return 0
}
