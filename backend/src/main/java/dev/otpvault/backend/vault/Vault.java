package dev.otpvault.backend.vault;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "vault")
public class Vault {

    @Id
    private UUID userId;

    @Column(nullable = false, columnDefinition = "text")
    private String envelope;

    @Column(nullable = false)
    private int version;

    @Column(nullable = false)
    private Instant updatedAt;

    protected Vault() {
    }

    public Vault(UUID userId, String envelope, Instant updatedAt) {
        this.userId = userId;
        this.envelope = envelope;
        this.version = 1;
        this.updatedAt = updatedAt;
    }

    public String getEnvelope() {
        return envelope;
    }

    public int getVersion() {
        return version;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }

    @Override
    public boolean equals(Object other) {
        if (this == other) {
            return true;
        }
        return other instanceof Vault vault && userId != null && userId.equals(vault.userId);
    }

    @Override
    public int hashCode() {
        return Vault.class.hashCode();
    }
}
