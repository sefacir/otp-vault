# Security checklist

Tracked against OWASP MASVS (mobile) and ASVS (backend). Filled in as milestones land.
Status: `-` not started, `~` in progress, `x` done, `n/a` not applicable.

## MASVS — mobile

| ID area | Item | Status | Notes |
|---------|------|--------|-------|
| STORAGE | Secrets in Keychain, not UserDefaults / plist | - | M2 |
| STORAGE | Keychain access control: device-only, biometry | - | M2 |
| STORAGE | No secrets in logs, backups, screenshots | - | M2 |
| CRYPTO  | Argon2id params chosen and documented | - | M4 |
| CRYPTO  | AES-256-GCM, unique nonce per encryption | - | M4 |
| CRYPTO  | No hardcoded keys | - | |
| AUTH    | App lock via LocalAuthentication | - | M2 |
| NETWORK | TLS only, ATS not weakened | - | M3 |
| NETWORK | Certificate pinning | - | M6 |
| RESILIENCE | Jailbreak detection | - | later |

## ASVS — backend

| ID area | Item | Status | Notes |
|---------|------|--------|-------|
| V2 Auth | Password hashing with Argon2id | x | Argon2PasswordEncoder v5.8 defaults |
| V2 Auth | Login timing constant for unknown vs known email | x | dummy-hash match on miss |
| V2 Auth | Rate limiting on auth endpoints | x | fixed window 10/60s, keyed by IP and by identifier |
| V2 Auth | Account lockout / throttling | x | 5 fails -> 15 min lock; atomic counter updates |
| V2 Auth | Registration does not leak account existence | ~ | still returns 409; accepted until email verification exists |
| V3 Session | Short-lived access token, rotating refresh | x | 15 min JWT (jti); refresh stored as SHA-256 hash, single-use |
| V3 Session | Refresh-token reuse detection | x | replay of a revoked token revokes the whole family |
| V3 Session | Locked account cannot mint tokens via refresh | x | refresh re-checks lock |
| V5 Validation | Request body validation on all endpoints | x | auth + vault DTOs validated (email, size caps) |
| V7 Logging | Auth + vault events logged, no PII/secrets | x | `audit.auth` / `audit.vault` loggers, userId only |
| V7 Data retention | Expired / revoked refresh tokens purged | x | hourly @Scheduled cleanup |
| V8 Data | Vault stored as ciphertext only | x | server stores opaque envelope; verified via live test |
| V8 Data | Schema managed by versioned migrations | x | Flyway V1; Hibernate ddl-auto=validate |
| V13 API | Rate limit on vault writes | x | 10 / 60s per user on PUT /vault |
| V3 Session | Access token has issuer claim, validated | x | `iss=otp-vault`, parser requireIssuer |
| V9 Comms | HSTS header + optional HTTPS-only | x | HSTS 1y; `requiresChannel` gated by `otpvault.security.require-https` |
| V9 Comms | Correct client IP behind proxy | x | `server.forward-headers-strategy=framework` |
| CRYPTO | Vault key derivation (PBKDF2-HMAC-SHA256, 600k) | x | client-side; key never sent to server |
| CRYPTO | Vault encryption AES-256-GCM, fresh salt + nonce per seal | x | VaultCrypto, 8 tests |
| V13 API | Actuator locked down except /actuator/health | x | /actuator/** denyAll |
| V14 Config | Secrets from env, not committed | ~ | dev JWT secret has a default; startup fails if used with prod profile |
| V14 Config | Client IP behind proxy | - | rate limiter trusts remoteAddr; needs forward-headers config when proxied |

## Supply chain

| Item | Status | Notes |
|------|--------|-------|
| Secret scanning in CI (gitleaks) | x | M0, full history |
| Dependency scanning (Trivy, fail on HIGH/CRITICAL) | x | M6; caught + fixed CVE-2025-14813 (bcprov 1.78.1 -> 1.85.2) |
| Automated dependency updates (Dependabot) | x | M6; maven + swift + github-actions, weekly |
| SBOM generated in CI (CycloneDX) | x | M6; backend `cyclonedx-maven-plugin` + repo-wide Trivy SBOM, uploaded as artifacts |
