// Content Validator — report formatting.
// Prints colored pass/fail for each result, then a summary line.
using std::string
using std::string_view
using std::vector

public namespace content_validator {

    // Print the report. Returns true if any check failed.
    public func print_report(results : *vector<ValidationResult>) : bool {
        var passed_count : int = 0
        var failed_count : int = 0
        var total = results.size()

        var i : size_t = 0
        while(i < total) {
            var r = results.get_ptr(i)
            if(r.passed) {
                printf("  PASS  %s", r.check_name.data())
                if(r.message.size() > 0) {
                    printf(" — %s", r.message.data())
                }
                printf("\n")
                passed_count = passed_count + 1
            } @else {
                printf("  FAIL  %s", r.check_name.data())
                if(r.message.size() > 0) {
                    printf(" — %s", r.message.data())
                }
                if(r.file_path.size() > 0) {
                    printf(" [%s]", r.file_path.data())
                }
                printf("\n")
                failed_count = failed_count + 1
            }
            i = i + 1
        }

        printf("---\n")
        printf("Results: %d passed, %d failed, %d total\n", passed_count, failed_count, total as int)

        if(failed_count > 0) {
            printf("Status: FAILED\n")
            return true
        } @else {
            printf("Status: ALL PASSED\n")
            return false
        }
    }

}
