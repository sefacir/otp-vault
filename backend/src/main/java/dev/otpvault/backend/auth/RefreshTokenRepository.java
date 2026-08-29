package dev.otpvault.backend.auth;

import java.time.Instant;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

public interface RefreshTokenRepository extends JpaRepository<RefreshToken, UUID> {

    Optional<RefreshToken> findByTokenHash(String tokenHash);

    @Modifying
    @Transactional
    @Query("update RefreshToken t set t.revoked = true where t.userId = :userId and t.revoked = false")
    void revokeAllForUser(@Param("userId") UUID userId);

    @Modifying
    @Transactional
    @Query("delete from RefreshToken t where t.expiresAt < :cutoff or t.revoked = true")
    int deleteExpiredOrRevoked(@Param("cutoff") Instant cutoff);
}
