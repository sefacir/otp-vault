package dev.otpvault.backend.auth;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Index;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "refresh_token", indexes = @Index(name = "idx_refresh_token_user", columnList = "userId"))
public class RefreshToken {

    @Id
    private UUID id;

    @Column(nullable = false)
    private UUID userId;

    @Column(nullable = false, unique = true, length = 64)
    private String tokenHash;

    @Column(nullable = false)
    private Instant expiresAt;

    @Column(nullable = false)
    private boolean revoked;

    protected RefreshToken() {
    }

    public RefreshToken(UUID userId, String tokenHash, Instant expiresAt) {
        this.id = UUID.randomUUID();
        this.userId = userId;
        this.tokenHash = tokenHash;
        this.expiresAt = expiresAt;
        this.revoked = false;
    }

    public UUID getUserId() {
        return userId;
    }

    public boolean isRevoked() {
        return revoked;
    }

    public boolean isExpired(Instant now) {
        return !expiresAt.isAfter(now);
    }

    public void revoke() {
        this.revoked = true;
    }

    @Override
    public boolean equals(Object other) {
        if (this == other) {
            return true;
        }
        return other instanceof RefreshToken token && id != null && id.equals(token.id);
    }

    @Override
    public int hashCode() {
        return RefreshToken.class.hashCode();
    }
}
