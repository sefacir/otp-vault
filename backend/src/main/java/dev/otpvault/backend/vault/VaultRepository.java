package dev.otpvault.backend.vault;

import java.time.Instant;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

public interface VaultRepository extends JpaRepository<Vault, UUID> {

    @Modifying
    @Transactional
    @Query("update Vault v set v.envelope = :envelope, v.version = v.version + 1, v.updatedAt = :now "
            + "where v.userId = :userId and v.version = :expectedVersion")
    int applyUpdate(
            @Param("userId") UUID userId,
            @Param("envelope") String envelope,
            @Param("expectedVersion") int expectedVersion,
            @Param("now") Instant now);
}
