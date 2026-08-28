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

## Architecture

| Layer   | Stack |
|---------|-------|
| iOS     | Swift, SwiftUI, Keychain / Secure Enclave, LocalAuthentication |
| Backend | Java, Spring Boot, PostgreSQL |
| Crypto  | Argon2id key derivation, AES-256-GCM vault encryption, zero-knowledge server |

## Layout

```
ios/        iOS app (Xcode)
backend/    Spring Boot service (IntelliJ IDEA)
docs/       roadmap, decisions, security checklist
```

## Docs

- [Roadmap](docs/roadmap.md)
- [Decisions](docs/decisions.md)
- [Security checklist](docs/security-checklist.md)
