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
- [ ] Camera QR scanner feeding OtpAuthURI
- [x] Store secrets in Keychain (device-only; biometry gate lands with app lock)
- [ ] App lock screen via LocalAuthentication
- [x] Delete account (swipe); edit still pending

## M3 — Backend authentication

Done when: signup and login work, issue JWTs, rate limiting and account lockout are in
place, data is in PostgreSQL.

- [ ] PostgreSQL via docker-compose for local dev
- [ ] User entity, signup with password hashing (Argon2id)
- [ ] Login, short-lived access JWT + refresh token
- [ ] Rate limiting on auth endpoints
- [ ] Account lockout after repeated failures

## M4 — Encrypted backup

Done when: the vault is encrypted on-device and the ciphertext blob round-trips to the
backend.

- [ ] Derive vault key from master password (Argon2id), never sent to server
- [ ] Encrypt vault with AES-256-GCM
- [ ] `PUT /vault` / `GET /vault`: one ciphertext blob per user, with version
- [ ] iOS backup flow

## M5 — Restore flow

Done when: on a fresh device, sign in, download the blob, enter the master password, and
all accounts come back.

- [ ] iOS restore flow end to end
- [ ] Conflict handling (server version vs local)
- [ ] Wrong-password path fails cleanly

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
