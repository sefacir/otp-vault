package dev.otpvault.backend.vault;

import java.time.Instant;

record VaultResult(int version, Instant updatedAt) {
}
