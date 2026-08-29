# Roadmap

Milestones are checkpoints. Each groups a few issues that together produce something
that visibly works. GitHub Milestones hold the issues; when the bar fills, the milestone
is done.

## M0 — Repo skeleton

Done when: monorepo in place, Spring backend boots, `/health` returns OK, CI runs build +
secret scan and is green.

- [x] Folder structure and README
- [x] `.gitignore` for Java, Xcode, macOS, IntelliJ
- [x] Spring Boot project in `backend/` (web + actuator)
- [x] `GET /health` endpoint
- [x] GitHub Actions: build backend, run gitleaks
- [x] First push to GitHub

## M1 — TOTP core (iOS)

Done when: a manually entered secret produces the correct 6-digit code, shown in a list
with a countdown ring.

- [x] Xcode project in `ios/` (OtpVault app target linked to OtpVaultCore)
- [x] RFC 6238 TOTP implementation (HMAC-SHA1/256/512, configurable period + digits)
- [x] Unit tests against RFC 6238 test vectors
- [x] Manual "add account" form (issuer, label, secret)
- [x] Account list with live code + countdown ring

## M2 — QR entry + local encrypted storage

Done when: an `otpauth://` QR is scanned into an account, secrets sit encrypted in the
Keychain, and the app is gated behind Face ID / passcode.

- [x] Parse `otpauth://totp/...` (OtpAuthURI, 11 tests)
- [x] Camera QR scanner feeding OtpAuthURI (VisionKit DataScanner; graceful fallback without camera)
- [x] Store secrets in Keychain (device-only; biometry gate lands with app lock)
- [x] App lock screen via LocalAuthentication (biometry + passcode, re-locks on background)
- [x] Delete account (swipe) and edit issuer/label

## M3 — Backend authentication

Done when: signup and login work, issue JWTs, rate limiting and account lockout are in
place, data is in PostgreSQL.

- [x] PostgreSQL via docker-compose for local dev (Spring Data JPA wired, CI has a pg service)
- [x] User entity, signup with password hashing (Argon2id)
- [x] Login, short-lived access JWT (15 min) + rotating stored refresh token (7 days)
- [x] Rate limiting on auth endpoints (10 / 60s per IP + action)
- [x] Account lockout after repeated failures (5 fails -> 15 min lock)

## M4 — Encrypted backup

Done when: the vault is encrypted on-device and the ciphertext blob round-trips to the
backend.

- [x] Derive vault key from master password (PBKDF2-HMAC-SHA256, 600k iters), never sent to server
- [x] Encrypt vault with AES-256-GCM (VaultCrypto + BackupEnvelope, 8 tests)
- [x] `GET` / `PUT` / `DELETE /vault`: one opaque envelope per user, optimistic version (11 tests)
- [x] BackendClient (13 tests) + VaultSync push/pull/retry (10 tests)
- [x] iOS backup flow: Session (tokens in Keychain), BackupView, sign in + back up, verified end-to-end

## M5 — Restore flow

Done when: on a fresh device, sign in, download the blob, enter the master password, and
all accounts come back.

- [x] iOS restore flow end to end (VaultSync.pullWithRetry + BackupView "Restore", verified)
- [x] Conflict handling (server version vs local) — pushWithRetry re-reads version, local wins
- [x] Wrong-password path fails cleanly ("Wrong master password", local accounts untouched)

## M6 — Hardening

Done when: pinning is on, MASVS/ASVS review is done, dependency + secret scans are green,
docs are current.

- [ ] Certificate pinning on iOS
- [ ] MASVS review pass, findings logged
- [ ] ASVS review pass, findings logged
- [ ] Dependency scanning (Dependabot / Trivy) green
- [ ] SBOM generated in CI

## Later

HOTP and Steam codes, web client with in-browser decryption, multi-device sync,
import from Google Authenticator / Aegis, TestFlight release.
