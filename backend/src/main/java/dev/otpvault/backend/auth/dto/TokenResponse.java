package dev.otpvault.backend.auth.dto;

public record TokenResponse(
        String accessToken,
        String refreshToken,
        long expiresInSeconds) {
}
