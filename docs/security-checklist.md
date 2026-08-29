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
| V2 Auth | Rate limiting on auth endpoints | x | in-memory fixed window, 10/60s |
| V2 Auth | Account lockout / throttling | x | 5 fails -> 15 min lock |
| V3 Session | Short-lived access token, rotating refresh | x | 15 min JWT; refresh stored as hash, rotated on use |
| V5 Validation | Request body validation on all endpoints | ~ | auth DTOs validated; revisit for /vault in M4 |
| V7 Logging | Auth events logged, no secrets in logs | - | M6 |
| V8 Data | Vault stored as ciphertext only | - | M4 |
| V14 Config | Secrets from env, not committed | - | M0 |

## Supply chain

| Item | Status | Notes |
|------|--------|-------|
| Secret scanning in CI (gitleaks) | x | M0, full history |
| Dependency scanning (Dependabot / Trivy) | - | M6 |
| SBOM generated in CI | - | M6 |
