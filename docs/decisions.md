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
  per 60s per IP + action. Move to Redis/Bucket4j if this ever runs multi-instance.

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
