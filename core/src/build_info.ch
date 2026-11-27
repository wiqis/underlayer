// underlayer_core — build provenance for /api/health (H5).
//
// The four values are runtime inputs with deliberately LOUD defaults. A debug
// build may boot with `unknown`/`debug`; a release build that cannot name its
// own source must not boot at all (validate_build_info is called from main()
// before schema init and before the accept loop). No value here is a secret.
//
// Env inputs (set by the build/deploy step, see docs/deployment.md §4a):
//   UL_BUILD_COMMIT            git commit / source digest of this binary
//   UL_BUILD_COMPILER_VERSION  exact `TCCCompiler --version` output
//   UL_BUILD_MODE              "release" for deployed artifacts
//   UL_BUILD_AT                ISO-8601 UTC build timestamp
using std::string
using std::string_view

public namespace underlayer_core {

    public struct BuildInfo {
        var commit : std::string
        var compiler_version : std::string
        var build_mode : std::string
        var built_at : std::string
    }

    private func env_or(name : *char, fallback : &std::string) : std::string {
        var value = get_env_str(name)
        if(value.empty()) { return fallback.copy() }
        return value
    }

    public func current_build_info() : BuildInfo {
        var unknown = std::string("unknown")
        var debug = std::string("debug")
        return BuildInfo {
            commit = env_or("UL_BUILD_COMMIT", &unknown),
            compiler_version = env_or("UL_BUILD_COMPILER_VERSION", &unknown),
            build_mode = env_or("UL_BUILD_MODE", &debug),
            built_at = env_or("UL_BUILD_AT", &unknown)
        }
    }

    private func is_unset(value : &std::string) : bool {
        if(value.empty()) { return true }
        var unknown = std::string("unknown")
        return value.equals(&unknown)
    }

    // True when this binary is allowed to serve. A non-release build is a local
    // test binary and may carry placeholders; a release build must carry all
    // three identifying values or fail loudly at startup.
    public func validate_build_info(bi : &BuildInfo) : bool {
        var release = std::string("release")
        if(!bi.build_mode.equals(&release)) { return true }
        if(is_unset(&bi.commit)) { return false }
        if(is_unset(&bi.compiler_version)) { return false }
        if(is_unset(&bi.built_at)) { return false }
        return true
    }

    public func build_info_failure_message(bi : &BuildInfo) : std::string {
        var msg = std::string("[underlayer] FATAL: UL_BUILD_MODE=release requires build provenance.\n")
        msg.append_view("  UL_BUILD_COMMIT=")
        msg.append_view(bi.commit.to_view())
        msg.append_view("\n  UL_BUILD_COMPILER_VERSION=")
        msg.append_view(bi.compiler_version.to_view())
        msg.append_view("\n  UL_BUILD_AT=")
        msg.append_view(bi.built_at.to_view())
        msg.append_view("\n  Set all three, or use UL_BUILD_MODE=debug for a local test binary.\n")
        return msg
    }

    public func build_info_startup_line(bi : &BuildInfo) : std::string {
        var msg = std::string("[underlayer] provenance commit=")
        msg.append_view(bi.commit.to_view())
        msg.append_view(" compiler_version=")
        msg.append_view(bi.compiler_version.to_view())
        msg.append_view(" build_mode=")
        msg.append_view(bi.build_mode.to_view())
        msg.append_view(" built_at=")
        msg.append_view(bi.built_at.to_view())
        return msg
    }

    private func append_json_field(body : &mut std::string, key : &std::string_view, value : &std::string) {
        body.append_view(", \"")
        body.append_view(key)
        body.append_view("\": \"")
        var escaped = json_escape(value.to_view())
        body.append_view(escaped.to_view())
        body.append('"')
    }

    // Additive health payload. `status` and `version` keep their exact bytes;
    // clients and the served-behaviour checkers parse only those two fields.
    public func health_json_with_build_info() : std::string {
        var bi = current_build_info()
        var body = std::string("{\"status\": \"ok\", \"version\": \"0.1.0\"")
        var commit_key = std::string_view("commit")
        var compiler_key = std::string_view("compiler_version")
        var mode_key = std::string_view("build_mode")
        var at_key = std::string_view("built_at")
        append_json_field(&mut body, &commit_key, &bi.commit)
        append_json_field(&mut body, &compiler_key, &bi.compiler_version)
        append_json_field(&mut body, &mode_key, &bi.build_mode)
        append_json_field(&mut body, &at_key, &bi.built_at)
        body.append('}')
        return body
    }
}
