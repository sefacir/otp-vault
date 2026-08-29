# Security checklist

Reviewed against OWASP MASVS (mobile) and ASVS (backend). Status: `-` not started,
`~` partial / accepted gap, `x` done, `n/a` not applicable. Last full pass: M6,
plus a line-by-line audit fix pass on 2026-08-29 (see `decisions.md`).

## MASVS — iOS app

| Area | Item | Status | Notes |
|------|------|--------|-------|
| STORAGE | TOTP secrets + tokens in the Keychain, never UserDefaults / plist | x | `AccountStore` via `CodableStore`, `Session` via `TokenStore`; only the vault version number is in UserDefaults |
| STORAGE | Keychain items are device-only, not synced or backed up | x | `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` |
| STORAGE | Corrupt local store never silently discards real data | x | decode failure loads empty and keeps the bad blob (does not re-seed samples) |
| STORAGE | No secrets in logs | x | no secret is printed / os_log'd |
| STORAGE | Codes not exposed in the app-switcher snapshot | x | `AppLock` shows an opaque cover whenever the scene is not `.active` |
| CRYPTO | Vault key from a real KDF, never sent to the server | x | PBKDF2-HMAC-SHA256, 600k iters (Argon2id deferred to keep zero SPM deps) |
| CRYPTO | Vault encrypted with AES-256-GCM, fresh salt + nonce per seal | x | `VaultCrypto` |
| CRYPTO | KDF params authenticated so a hostile server cannot weaken them | x | params bound into the GCM AAD; envelope format 2; `open` rejects tampered params and non-2 formats |
| CRYPTO | No hardcoded keys | x | every key derives from the master password |
| AUTH | App lock behind Face ID / passcode, re-locks on background | x | `AppLock` + `LocalAuthentication` |
| NETWORK | ATS not weakened except localhost dev | x | `NSAllowsLocalNetworking` only |
| NETWORK | Certificate pinning available | x | `CertificatePinning` + `PinnedSessionDelegate`, driven by `OTPVAULT_PINNED_CERT_SHA256`; empty (off) in dev — populate for prod |
| RESILIENCE | Jailbreak detection, non-blocking | x | `DeviceIntegrity` + warning banner |
| RESILIENCE | Anti-debug / release hardening | ~ | relies on the Xcode Release build; no extra checks |
| CODE | Third-party components minimised | x | `OtpVaultCore` and the app have zero external dependencies |

## ASVS — backend

| Area | Item | Status | Notes |
|------|------|--------|-------|
| Auth | Password hashing with Argon2id | x | `Argon2PasswordEncoder` v5.8 defaults |
| Auth | Constant-time login for unknown vs known email | x | dummy-hash `matches` on miss |
| Auth | Rate limiting on auth endpoints | x | fixed window 10 / 60s, keyed by IP and by identifier |
| Auth | Account lockout after repeated failures | x | 5 fails -> 15 min lock; atomic counter updates |
| Auth | Registration does not leak account existence | ~ | returns 409; accepted until email verification exists. Check-then-insert race also maps to 409 (`DataIntegrityViolationException` caught) |
| Auth | Locale-independent identifier handling | x | `toLowerCase(Locale.ROOT)` for email normalisation and rate-limit keys |
| Session | Short-lived access token + rotating refresh | x | 15 min JWT with `jti` + `iss`; refresh stored as SHA-256 hash, single-use |
| Session | Refresh-token reuse detection | x | replaying a revoked token revokes the whole family |
| Session | Locked account cannot mint tokens via refresh | x | `refresh` re-checks the lock |
| Session | Access token issuer claim validated | x | `iss=otp-vault`, parser `requireIssuer` |
| Session | Access token can be revoked before expiry | x | `POST /auth/logout` denylists the `jti` until its expiry + revokes the refresh family; in-memory (single-instance, like the rate limiter) |
| Auth | Lockout response is not a timing oracle | x | 423 with `{error: account_locked}` only; no `until` timestamp |
| Access control | Vault is strictly per-user, no IDOR | x | vault PK is the userId from the token |
| Validation | Request bodies validated (email, size caps) | x | auth + vault DTOs; `/vault` envelope capped at 1 MB |
| Injection | No SQLi | x | all queries are parameterised JPQL / derived methods |
| API | Rate limit on vault writes | x | 10 / 60s per user on `PUT /vault` |
| API | Actuator locked to `/actuator/health` only | x | `/actuator/**` denyAll |
| Comms | HSTS header + optional HTTPS-only | x | HSTS 1y; `requiresChannel` gated by `otpvault.security.require-https` |
| Comms | Correct client IP behind a proxy | x | `server.forward-headers-strategy=${OTPVAULT_FORWARD_HEADERS:none}` — default off so a spoofed `X-Forwarded-For` cannot split the rate-limit bucket; enable only behind a trusted proxy |
| Logging | Auth + vault events audited, no PII / secrets | x | `audit.auth` / `audit.vault`, userId UUID only |
| Data | Vault stored as an opaque ciphertext envelope | x | server never parses it |
| Data | Expired / revoked refresh tokens purged | x | hourly `@Scheduled` cleanup; `TokenDenylist` sweeps expired `jti`s every 5 min |
| Config | Schema via versioned migrations | x | Flyway `V1__init.sql`; Hibernate `ddl-auto=validate` |
| Config | JWT secret from env, no fallback | x | `OTPVAULT_JWT_SECRET` required; `JwtService` refuses a blank / sub-32-byte secret at startup in every profile |
| Errors | No stack traces / internals in responses | x | `@RestControllerAdvice` returns `{error: ...}`; malformed JSON -> 400, `DataIntegrityViolationException` -> 409, never a 500 with internals |

## Supply chain (CI)

| Item | Status | Notes |
|------|--------|-------|
| Secret scanning (gitleaks, full history) | x | M0 |
| Dependency scanning (Trivy, fail on HIGH/CRITICAL) | x | M6; caught + fixed CVE-2025-14813 (bcprov 1.78.1 -> 1.85.2) |
| Automated dependency updates (Dependabot) | x | M6; maven + swift + github-actions, weekly |
| SBOM (CycloneDX) generated + archived | x | M6; `cyclonedx-maven-plugin`, uploaded as a CI artifact |
