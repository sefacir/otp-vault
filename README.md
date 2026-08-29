# otp-vault

An iOS 2FA authenticator with an end-to-end encrypted, zero-knowledge cloud backup.

Generates rotating TOTP codes like Google Authenticator, but your accounts survive a lost
phone: the vault is encrypted on-device with a key derived from your master password and
only the ciphertext is stored on the server. The server never sees your secrets.

## Status

Early. This is a learning project focused on mobile application security and full-stack
security. The cryptography has not been independently reviewed. Do not rely on it for
anything you cannot afford to lose yet.

## Goals

1. Learn mobile AppSec and full-stack security hands-on: cryptography, secure storage,
   authentication, secure APIs, CI security.
2. Fill a real gap: iOS lacks a maintained open-source authenticator with encrypted backup.
3. Build in the open, one small commit at a time.

## Features

**iOS app**

- RFC 6238 TOTP (SHA-1 / SHA-256 / SHA-512, 6–8 digits, configurable period)
- Add accounts by QR scan (`otpauth://`) or manual entry
- Secrets and tokens in the Keychain, device-only, never in `UserDefaults` or a plist
- App lock behind Face ID / passcode, re-locks on background, masks the app-switcher snapshot
- Encrypted backup and restore against your own server
- Certificate pinning (opt-in), jailbreak warning banner
- `OtpVaultCore` holds all the logic and has zero external dependencies

**Backend**

- Argon2id password hashing
- Short-lived HS256 access token (`jti` + `iss`) plus an opaque rotating refresh token
  (stored hashed, single-use, reuse revokes the whole family)
- `POST /auth/logout` revokes the access token before it expires (jti denylist)
- Account lockout after repeated failures, in-memory rate limiting by IP and identifier
- `/vault` stores one opaque ciphertext envelope per user, optimistic versioning
- Flyway migrations, audit logging (user id only, no PII or secrets)

**Crypto**

- Vault key: PBKDF2-HMAC-SHA256, 600k iterations, derived on-device from the master password
- Vault: AES-256-GCM, fresh salt and nonce per seal, KDF params authenticated as GCM AAD
- The derived key never leaves the device; the server only ever sees the envelope

## Architecture

| Layer   | Stack |
|---------|-------|
| iOS     | Swift 6, SwiftUI, Keychain, LocalAuthentication, CryptoKit |
| Backend | Java 21, Spring Boot 4.1, Spring Security, PostgreSQL 17 |
| CI      | gitleaks (full history), Trivy on a CycloneDX SBOM (HIGH/CRITICAL gate), Dependabot |

## Layout

```
ios/        iOS app (Xcode) — OtpVaultCore package + OtpVault app
backend/    Spring Boot service (IntelliJ IDEA)
docs/       roadmap, decisions, security checklist
```

## Running it locally

**Backend**

```
cd backend
docker compose up -d
cp src/main/resources/application-local.properties.example src/main/resources/application-local.properties
./mvnw spring-boot:run
```

`application-local.properties` (git-ignored) supplies `OTPVAULT_JWT_SECRET`; the service
refuses to start without a secret of at least 32 bytes. `OTPVAULT_JWT_SECRET` as an
environment variable works too. The API listens on `http://localhost:8080`;
`GET /health` is the only browser-friendly endpoint.

**iOS**

Open `ios/OtpVault/OtpVault.xcodeproj` in Xcode and run. Point it at a local backend with
the `OTPVAULT_API_URL` Info.plist key. If Xcode shows phantom package errors, delete
`~/Library/Developer/Xcode/DerivedData/OtpVault-*` and reset package caches.

**Tests**

```
cd backend && ./mvnw verify
cd ios/OtpVaultCore && swift test
```

## Docs

- [Roadmap](docs/roadmap.md)
- [Decisions](docs/decisions.md)
- [Security checklist](docs/security-checklist.md)
