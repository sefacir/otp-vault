package dev.otpvault.backend.vault.dto;

import java.time.Instant;

public record VaultResponse(
        String envelope,
        int version,
        Instant updatedAt) {
}
