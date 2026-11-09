These unmodified notice fixtures come from OpenSSL commit `fe686e15d84334b284f883118ed92f64b409b3aa` (`openssl-3.6.2`) at https://github.com/openssl/openssl. The regression checks their Git blob identifiers before staging them in a synthetic build checkout:

| File | Git blob |
|---|---|
| `LICENSE.txt` | `49cc83d2ee29d13453188217f0e4edd70c7f842f` |
| `AUTHORS.md` | `5b036a0d8358167c87c7fa275cc671cd222dcce6` |
| `VERSION.dat` | `2407410ed5fecbe09d603c34892c533f6db03a12` |

No top-level `NOTICE` file exists in that source revision. The fixture adds a separately labeled synthetic notice to test optional-notice preservation. The generated fixture manifest records the synthetic checkout's own commit, without attributing a test binary to an upstream release.
