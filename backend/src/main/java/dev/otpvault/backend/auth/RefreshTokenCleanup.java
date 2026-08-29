package dev.otpvault.backend.auth;

import java.time.Instant;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Component
class RefreshTokenCleanup {

    private final RefreshTokenRepository refreshTokens;

    RefreshTokenCleanup(RefreshTokenRepository refreshTokens) {
        this.refreshTokens = refreshTokens;
    }

    @Scheduled(fixedDelayString = "PT1H", initialDelayString = "PT1M")
    void purge() {
        refreshTokens.deleteExpiredOrRevoked(Instant.now());
    }
}
