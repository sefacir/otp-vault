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
