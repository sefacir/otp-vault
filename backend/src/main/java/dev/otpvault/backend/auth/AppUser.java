package dev.otpvault.backend.auth;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "app_user")
public class AppUser {

    @Id
    private UUID id;

    @Column(nullable = false, unique = true)
    private String email;

    @Column(nullable = false)
    private String passwordHash;

    @Column(nullable = false)
    private Instant createdAt;

    @Column(nullable = false)
    private int failedLoginAttempts;

    private Instant lockedUntil;

    protected AppUser() {
    }

    public AppUser(String email, String passwordHash) {
        this.id = UUID.randomUUID();
        this.email = email;
        this.passwordHash = passwordHash;
        this.createdAt = Instant.now();
        this.failedLoginAttempts = 0;
    }

    public UUID getId() {
        return id;
    }

    public String getEmail() {
        return email;
    }

    public String getPasswordHash() {
        return passwordHash;
    }

    public int getFailedLoginAttempts() {
        return failedLoginAttempts;
    }

    public Instant getLockedUntil() {
        return lockedUntil;
    }

    public boolean isLocked(Instant now) {
        return lockedUntil != null && lockedUntil.isAfter(now);
    }

    @Override
    public boolean equals(Object other) {
        if (this == other) {
            return true;
        }
        return other instanceof AppUser user && id != null && id.equals(user.id);
    }

    @Override
    public int hashCode() {
        return AppUser.class.hashCode();
    }
}
