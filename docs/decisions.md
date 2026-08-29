# Decisions

Short log of choices and why, newest first.

## 2026-08-29 — Backend auth (M3)

- Spring Security 7 stateless filter chain; `/auth/register|login|refresh`, `/health`,
  `/actuator/**` are public, everything else needs a Bearer JWT.
- Passwords: `Argon2PasswordEncoder.defaultsForSpringSecurity_v5_8()` (Argon2id, needs
  BouncyCastle).
- Access token: HS256 JWT, 15 min, `jti` per token. Secret from `OTPVAULT_JWT_SECRET`
  (dev default in properties, must be >= 32 bytes).
- Refresh token: opaque random 256-bit, stored in DB as SHA-256 hash, single-use
  (rotated on `/auth/refresh`), 7 day TTL.
- Account lockout: 5 failed logins -> `lockedUntil` = now + 15 min. Failed-login
  bookkeeping must NOT be inside a `@Transactional` that also throws, or the counter
  rolls back.
- Rate limiting: hand-rolled in-memory fixed window (`ConcurrentHashMap`), 10 requests
  per 60s, keyed both by client IP and by identifier (email). An hourly `@Scheduled`
  sweep drops expired windows. Move to Redis/Bucket4j if this ever runs multi-instance.
- Rate limiter keys on `request.getRemoteAddr()`. Behind a reverse proxy this is the
  proxy IP (one shared bucket) unless `server.forward-headers-strategy` is set and the
  proxy is trusted to overwrite `X-Forwarded-For`. Not configured yet — dev runs direct.

## 2026-08-29 — Vault crypto (M4a)

- Client-side KDF is PBKDF2-HMAC-SHA256, 600k iterations, via CommonCrypto — chosen over
  Argon2id to keep `OtpVaultCore` dependency-free (no external SPM package to vet). The
  `BackupEnvelope` records `kdf.algorithm`, so moving to Argon2id later is a version bump.
- Vault is AES-256-GCM. `AES.GCM.SealedBox.combined` (nonce ‖ ciphertext ‖ tag) is stored
  base64 in the envelope; a fresh salt and nonce are generated on every `seal`.
- The derived key never leaves the device. The server stores the whole envelope
  (salt + KDF params + ciphertext). A malicious server could serve weak KDF params;
  signing the envelope is deferred to M6.
- Wrong master password surfaces as `CryptoError.decryptionFailed` (GCM tag mismatch),
  never a partial/garbage decrypt.

## 2026-08-29 — M6 hardening: supply chain + backend

Supply chain:
- Dependabot (`.github/dependabot.yml`) — weekly maven / swift / github-actions.
- `cyclonedx-maven-plugin` emits `META-INF/sbom/application.cdx.json` on every build,
  uploaded as a CI artifact. CI `dependency-scan` job runs `trivy sbom` on it and fails
  on HIGH/CRITICAL (scanning the SBOM avoids Maven Central 429s in CI).
- Bumped `bcprov-jdk18on` 1.78.1 -> 1.85.2 (Trivy flagged CVE-2025-14813).

Backend hardening:
- Flyway: `spring-boot-starter-flyway` (Boot 4 split the autoconfig into a module) +
  `flyway-database-postgresql`. `V1__init.sql` holds the current schema; Hibernate is now
  `ddl-auto=validate`. Existing local DBs need `docker compose down -v` once.
- JWT carries `iss=otp-vault`; the parser calls `requireIssuer`.
- `PUT /vault` is rate limited (10 / 60s per user) via the shared `RateLimiter`
  (`RateLimited` is now public so the vault package can throw it).
- Audit logging: `audit.auth` and `audit.vault` SLF4J loggers record register / login
  (success + failure reason) / lockout / refresh / refresh-reuse / vault create-update-
  delete-conflict. Subject is the userId UUID — no email, token, or hash is ever logged.
- HSTS header (1 year, includeSubDomains) always configured; `requiresChannel(secure)` is
  switched on only when `otpvault.security.require-https=true` (prod).
- `server.forward-headers-strategy=framework` so the rate limiter sees the real client IP
  behind a trusted proxy.

## 2026-08-29 — Pre-M6 full review

Top-to-bottom pass over everything through M5. All three targets build clean; 57 iOS-core
+ 24 backend tests green. No credentials in backend logs; security headers (nosniff,
frame DENY, no-store on /vault) confirmed live. No SQLi / IDOR / mass-assignment.

Fixed in this pass:
- `AccountStore.load` no longer overwrites the Keychain with sample data when the stored
  blob fails to decode — it now loads empty and preserves the bad blob (was a silent
  data-loss path on any schema change).
- Excluded `UserDetailsServiceAutoConfiguration` — kills the phantom "generated security
  password" startup log and the unused in-memory user.
- Added a `/vault` oversized-envelope (>1 MB) -> 400 test.

Deferred to M6 (hardening):
- B2 no rate limit on `PUT /vault`; B5 JWT has no `iss`/`aud`; B6 no auth audit logging;
  B7 no HSTS / HTTPS enforcement; B8 no dependency scanning (JJWT 0.12.6, BC 1.78.1);
  B9 Flyway instead of `ddl-auto=update`.
- I3 iOS `baseURL` hardcoded http + needs cert pinning; I4 master-password min length is
  only 8; I5 envelope KDF params are server-trusted (needs signing).
- T1 add an iOS app unit-test target (Session, AccountStore); T2 focused `JwtServiceTest`.

## 2026-08-29 — iOS restore flow (M5)

- `VaultSync.pullWithRetry` mirrors `pushWithRetry`: GET vault -> decrypt -> return
  plaintext + version; one token refresh on 401.
- `BackupView` gains a "Restore from backup" button behind a confirmation dialog
  ("Replace all local accounts?"). On success `AccountStore.replaceAll` swaps the whole
  list and persists to the Keychain.
- Wrong master password -> GCM tag mismatch -> `CryptoError.decryptionFailed` ->
  "Wrong master password"; the local vault is never touched on failure.
- Verified in the simulator: delete an account locally, restore, the account (and its
  working TOTP) comes back; wrong password shows the error and changes nothing.

## 2026-08-29 — iOS backup flow (M4c)

- `BackendClient` (URLSession, async) in `OtpVaultCore`, behind a `BackendAPI` protocol so
  `VaultSync` is testable with a fake. Status codes map to a small `ClientError` enum.
- `VaultSync.push` / `pull` orchestrate encode -> seal -> PUT and GET -> open -> decode.
  `pushWithRetry` handles 401 (refresh once) and 409 (re-read version, local wins).
- App: `Session` stores the access + refresh tokens in the Keychain and the last backup
  version in UserDefaults. `BackupView` does sign in / register and "Back up now".
- Dev backend URL is `http://localhost:8080`; the app has an ATS `NSAllowsLocalNetworking`
  exception via a real `Info.plist` (kept outside the file-system-synchronized group to
  avoid a duplicate-Info.plist build error).
- Verified end to end in the simulator: register -> sign in -> back up (v1) -> back up
  again (v2); the server row holds only the opaque `{kdf, cipher, blobBase64}` envelope.

## 2026-08-29 — Vault storage endpoints (M4b)

- One `vault` row per user (`userId` is the PK). Columns: `envelope` (text, opaque —
  the server never parses it), `version` (int), `updatedAt`.
- `GET /vault` -> 200 envelope or 404. `PUT /vault` upserts. `DELETE /vault` -> 204.
- Lost-update protection: `PUT` carries `expectedVersion`. First write must omit it (or
  send 0); an update must match the current version. The update runs as a single
  conditional `UPDATE ... WHERE version = :expected` (rows-affected = 0 -> 409), so two
  concurrent writers cannot both succeed. Concurrent first-time creates collide on the
  PK and the loser gets 409.
- All `/vault` routes require a Bearer access token (falls under `anyRequest().authenticated()`).

## 2026-08-29 — Backend auth hardening (post-review)

- Login timing: on unknown email we still run one `passwordEncoder.matches` against a
  throwaway hash so response time does not reveal whether the account exists.
- Failed-login counter and lock are applied with atomic `@Modifying` update queries, not
  read-modify-write on the entity, so concurrent bad logins cannot lose an increment.
  These repo methods are `@Transactional` on their own; `login()` is deliberately NOT
  `@Transactional` so the counter write survives the `InvalidCredentials` throw.
- Refresh tokens: replaying a token that is present but already revoked is treated as
  theft -> `revokeAllForUser` kills every refresh token for that user and the caller is
  forced to log in again. `refresh()` also re-checks account lock.
- `JwtService` refuses to start if the built-in dev secret is used while the `prod`
  profile is active.
- Actuator: only `/actuator/health/**` is public, `/actuator/**` is `denyAll`.
  Unauthenticated requests to protected endpoints return 401 (`HttpStatusEntryPoint`),
  not Spring's default 403.
- `AuthFlowTest` (MockMvc, hits Postgres) covers register/login/me, lockout, refresh
  rotation + reuse detection, rate limiting, and the timing-equal unknown-email path.

## 2026-08-29 — Backend persistence

- PostgreSQL 17 via `backend/docker-compose.yml` for local dev; CI runs a matching
  `postgres:17-alpine` service container.
- Spring Data JPA with `ddl-auto=update` for now. Switch to Flyway migrations before M6.
- Datasource creds are local-dev throwaway (`otpvault`/`otpvault`), overridable via
  `OTPVAULT_DB_*` env vars. No real secret in the repo.

## 2026-08-28 — Stack

- iOS native (Swift + SwiftUI), not Flutter or React Native. AppSec primitives (Keychain,
  Secure Enclave, biometrics, pinning) are first-class in native and the point of the
  project is to learn them.
- Backend in Java + Spring Boot. Familiar ground, keeps focus on the security work.
- PostgreSQL for storage.
- Monorepo: `ios/`, `backend/`, `docs/`.

## 2026-08-28 — Product

- Build a TOTP authenticator with zero-knowledge encrypted backup.
- MVP is iOS + backend. Web client and App Store release are deferred.
- Server stores only ciphertext; the vault key is derived on-device from the master
  password and never leaves it.

## 2026-08-28 — Crypto (intended, not yet reviewed)

- Key derivation: Argon2id.
- Vault encryption: AES-256-GCM.
- To be validated against MASVS-CRYPTO before M4 is called done.
