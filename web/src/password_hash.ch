// underlayer_web — Password hashing: bcrypt with a per-user random salt,
// plus a verified upgrade path for rows written by the old unsalted SHA-256.
//
// WHY THIS FILE EXISTS AT ALL.  Passwords used to be stored as a single,
// UNSALTED SHA-256 digest (`sha256_hex(password)` in handlers_auth.ch).  That
// is two defects wearing one line of code:
//
//   1. UNSALTED.  Two learners who typed the same password got byte-identical
//      rows, so a leaked table shows at a glance who shares a password, and
//      the whole table is one `hashcat` run against a rainbow table.
//   2. SINGLE-PASS.  SHA-256 is a general-purpose hash.  A GPU does billions
//      per second, so a six-character password falls in seconds.  A password
//      KDF is supposed to be deliberately SLOW; this one was deliberately fast.
//
// WHAT IS USED AND WHY.
//
//   The Chemical tree ships `lang/libs/bcrypt`, a pure-Chemical
//   crypt_blowfish implementation, so this is not a hand-rolled KDF and it is
//   not a dependency we would have to keep alive.  It was checked against a
//   reference implementation before being trusted, not after:
//
//     $2b$06$If6bvum7DFjUnE9p2uDeDu0YHzrHM6tf.iqN8.yx.jNN1ILEf7h0i
//       + "abcdefghijklmnopqrstuvwxyz"
//       -> Chemical bcrypt::bf_crypt
//          $2b$06$If6bvum7DFjUnE9p2uDeDugSm/r4ClComu5mWRI4RIK8QxNtrr8pm
//       -> python3 -c "import bcrypt; print(bcrypt.hashpw(b'abcdefghijklmnopqrstuvwxyz',
//                                       b'$2b$06$If6bvum7DFjUnE9p2uDeDu').decode())"
//          $2b$06$If6bvum7DFjUnE9p2uDeDugSm/r4ClComu5mWRI4RIK8QxNtrr8pm
//
//   Byte-identical.  tools/security_check.py re-derives that comparison on
//   every run, so if the library ever stops agreeing with a reference bcrypt,
//   the gate fails instead of the passwords quietly changing meaning.
//
// COST.  12 is the bcrypt work factor: 2^12 = 4096 rounds of the expensive
// key schedule, which puts a single guess in the tens-of-milliseconds range on
// a modern core.  It is carried INSIDE the stored string (the `$2b$12$`
// prefix), so raising it later is a re-login-time upgrade of old rows, not a
// migration -- which is exactly the property the old bare hex digest did not
// have, and the reason this fix is safe to make now rather than never.
//
// WHY THE STORED STRING IS SELF-DESCRIBING.  bcrypt's own format already is:
// `$2b$` version, `12` cost, 22 base64 salt chars, 31 base64 digest chars.  So
// there is no separate column, no schema change and no migration: a row's
// algorithm and work factor can be read off the row.  That is the difference
// between a fix and a debt.
//
// THE LEGACY PATH.  Existing rows hold 64 lowercase hex characters and cannot
// be told apart from a digest by shape alone -- 64 hex chars is also a valid
// length for other things -- so `verify_password` decides by CONTENT: a bcrypt
// string always starts with `$2`, and the legacy form never can.  A learner
// with an old row still logs in (that is the whole point), and the caller
// re-hashes on the spot, so the fleet migrates itself one successful login at
// a time and no account is ever locked out.
//
// WHY THE COMPARISON IS CONSTANT-TIME.  `bcrypt::check_password` compares the
// recomputed hash with `.equals()`, which returns at the first differing byte.
// That leaks, over a network, how many leading characters of a hash matched.
// The comparison here walks all 60 bytes with `crypto::constant_time_equal`
// and accumulates the difference instead, so a wrong password costs the same
// time as a right one.
using std::string
using std::string_view

public namespace underlayer_web {

    // The work factor for newly stored passwords.  Deliberately a named
    // constant and not a literal at the call sites: it is the one number a
    // future hardening pass has to raise, and it should be raised in one place.
    public const PASSWORD_COST : int = 12

    // Length of a bcrypt modular-crypt string: $2b$NN$ + 53 base64 chars.
    public const BCRYPT_HASH_LEN : size_t = 60

    private func looks_like_bcrypt(stored : *string) : bool {
        if(stored.size() < 4u) { return false }
        if(stored.get(0) != '$') { return false }
        if(stored.get(1) != '2') { return false }
        // 4th char is the cost tens digit; a bcrypt setting always has one.
        if(stored.get(3) != '$') { return false }
        return true
    }

    private func looks_like_legacy_sha256_hex(stored : *string) : bool {
        if(stored.size() != 64u) { return false }
        var i : size_t = 0
        while(i < 64u) {
            var c = stored.get(i)
            var is_digit = c >= '0' && c <= '9'
            var is_lower = c >= 'a' && c <= 'f'
            if(!is_digit && !is_lower) { return false }
            i = i + 1
        }
        return true
    }

    // Hash a password for storage.  Returns the bcrypt modular-crypt string,
    // which carries its own version, salt and work factor.
    public func hash_password(password : *string) : string {
        if(password.size() == 0) { return string() }
        return bcrypt::hash_password(password.to_view())
    }

    // Which scheme a stored value is in.  Callers use this to decide whether a
    // successful login has just earned an upgrade.
    public func password_is_legacy_sha256(stored : *string) : bool {
        return looks_like_legacy_sha256_hex(stored)
    }

    // Verify a candidate password against a stored value, accepting BOTH the
    // current bcrypt form and the legacy unsalted SHA-256 form.
    //
    // Returns true only when the password is right.  It deliberately does NOT
    // report which scheme matched -- that is the caller's job via
    // password_is_legacy_sha256(), and keeping it separate stops a caller from
    // accidentally upgrading a row it has not actually matched.
    public func verify_password(password : *string, stored : *string) : bool {
        if(password.size() == 0 || stored.size() == 0) { return false }

        if(looks_like_bcrypt(stored)) {
            // Recompute using the stored salt and cost, then compare all 60
            // bytes in constant time.
            if(stored.size() != BCRYPT_HASH_LEN) { return false }
            var setting = stored.to_view().subview(0u, 29u)
            var computed = bcrypt::bf_crypt(password.to_view(), setting)
            if(computed.size() != BCRYPT_HASH_LEN) { return false }
            var a = computed.data() as *u8
            var b = stored.data() as *u8
            return crypto::constant_time_equal(a, b, BCRYPT_HASH_LEN)
        }

        if(looks_like_legacy_sha256_hex(stored)) {
            // The old scheme: one unsalted SHA-256, compared byte for byte.
            // Kept ONLY so an existing learner is not locked out.  Any row that
            // still verifies this way is rewritten in bcrypt by the caller.
            var digest : [32]u8
            var di : size_t = 0
            while(di < 32u) { digest[di] = 0; di = di + 1 }
            crypto::sha256_hash(password.data() as *u8, password.size(), &raw mut digest[0])
            var hex_out : [65]char
            var hi : size_t = 0
            while(hi < 65u) { hex_out[hi] = 0; hi = hi + 1 }
            encoding::hex_encode(&raw digest[0], 32u, &raw mut hex_out[0], 65u)
            var i : size_t = 0
            while(i < 64u) {
                if(hex_out[i] != stored.get(i)) { return false }
                i = i + 1
            }
            return true
        }

        // An unrecognised stored value must never authenticate anyone.
        return false
    }

    // The work factor a bcrypt stored string claims.  Exposed so a future
    // "rehash on login if the cost went up" pass has a number to compare
    // against PASSWORD_COST, and so tools/security_check.py can assert the
    // stored rows really do carry the factor this build claims to use.
    public func bcrypt_cost_of(stored : *string) : int {
        if(!looks_like_bcrypt(stored)) { return 0 }
        if(stored.size() < 7u) { return 0 }
        var tens = stored.get(4) - '0' as char
        var ones = stored.get(5) - '0' as char
        return ((tens as i32) * 10 + (ones as i32))
    }

}