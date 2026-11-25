// underlayer_core — THE SHARED ACCOUNT SERVICE URL.
//
// WHY THIS IS A FUNCTION AND NOT A CONSTANT.  Chemical's file-scope
// `string_view` constants fail at the C translation stage with no source
// location (see wiqis-chemical-language), and a `@never_destructed string`
// global reads back EMPTY at request time because nothing ever constructed it.
// Reading the environment on demand costs one `getenv` per call and cannot be
// stale or half-initialised, so every consumer — the CSP builder, the embedded
// sign-in frames and the shadow-learner bridge — resolves the same value the
// same way.
//
// `ACCOUNT_URL` is the fleet-wide variable (Timeline and easyToDo read it too).
// The default is the production shared-login host; a local run that points at
// a debug account service sets the variable explicitly.
public namespace underlayer_core {

    public func account_url() : std::string {
        var configured = get_env_str("ACCOUNT_URL")
        if(!configured.empty()) { return configured }
        return std::string("https://account.wiqis.com")
    }

}
