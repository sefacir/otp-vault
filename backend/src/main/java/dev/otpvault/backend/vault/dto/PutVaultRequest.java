package dev.otpvault.backend.vault.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record PutVaultRequest(
        @NotBlank @Size(max = 1_000_000) String envelope,
        Integer expectedVersion) {
}
