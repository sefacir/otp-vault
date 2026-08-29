package dev.otpvault.backend.auth;

import java.time.Instant;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Component
public class TokenDenylist {

    private final ConcurrentHashMap<String, Instant> revoked = new ConcurrentHashMap<>();

    public void revoke(String jti, Instant expiresAt) {
        if (jti != null && expiresAt != null && expiresAt.isAfter(Instant.now())) {
            revoked.put(jti, expiresAt);
        }
    }

    public boolean isRevoked(String jti) {
        Instant expiresAt = revoked.get(jti);
        if (expiresAt == null) {
            return false;
        }
        if (expiresAt.isBefore(Instant.now())) {
            revoked.remove(jti);
            return false;
        }
        return true;
    }

    @Scheduled(fixedDelay = 300_000L)
    void sweepExpired() {
        Instant now = Instant.now();
        revoked.entrySet().removeIf(entry -> entry.getValue().isBefore(now));
    }

    public void reset() {
        revoked.clear();
    }
}
