package dev.otpvault.backend.auth;

import java.time.Instant;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

public interface UserRepository extends JpaRepository<AppUser, UUID> {

    Optional<AppUser> findByEmail(String email);

    boolean existsByEmail(String email);

    @Modifying
    @Transactional
    @Query("update AppUser u set u.failedLoginAttempts = u.failedLoginAttempts + 1 where u.id = :id")
    void incrementFailedAttempts(@Param("id") UUID id);

    @Modifying
    @Transactional
    @Query("update AppUser u set u.lockedUntil = :until, u.failedLoginAttempts = 0 where u.id = :id")
    void lockUntil(@Param("id") UUID id, @Param("until") Instant until);

    @Modifying
    @Transactional
    @Query("update AppUser u set u.failedLoginAttempts = 0, u.lockedUntil = null where u.id = :id")
    void clearLoginFailures(@Param("id") UUID id);
}
