package dev.otpvault.backend.auth;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Duration;
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

    public void registerFailedLogin(int maxAttempts, Duration lockDuration, Instant now) {
        this.failedLoginAttempts++;
        if (this.failedLoginAttempts >= maxAttempts) {
            this.lockedUntil = now.plus(lockDuration);
            this.failedLoginAttempts = 0;
        }
    }

    public void registerSuccessfulLogin() {
        this.failedLoginAttempts = 0;
        this.lockedUntil = null;
    }
}
