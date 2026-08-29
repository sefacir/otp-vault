package dev.otpvault.backend.vault;

import dev.otpvault.backend.vault.dto.VaultResponse;
import java.time.Instant;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class VaultService {

    private static final Logger audit = LoggerFactory.getLogger("audit.vault");

    private final VaultRepository vaults;

    public VaultService(VaultRepository vaults) {
        this.vaults = vaults;
    }

    @Transactional(readOnly = true)
    public VaultResponse get(UUID userId) {
        Vault vault = vaults.findById(userId).orElseThrow(VaultNotFound::new);
        return new VaultResponse(vault.getEnvelope(), vault.getVersion(), vault.getUpdatedAt());
    }

    @Transactional
    public VaultResult save(UUID userId, String envelope, Integer expectedVersion) {
        int expected = expectedVersion == null ? 0 : expectedVersion;
        Instant now = Instant.now();

        if (expected == 0) {
            if (vaults.existsById(userId)) {
                audit.warn("vault put conflict reason=exists user={}", userId);
                throw new VaultVersionConflict();
            }
            try {
                vaults.save(new Vault(userId, envelope, now));
            } catch (DataIntegrityViolationException concurrentCreate) {
                audit.warn("vault put conflict reason=concurrent-create user={}", userId);
                throw new VaultVersionConflict();
            }
            audit.info("vault created user={}", userId);
            return new VaultResult(1, now);
        }

        int updated = vaults.applyUpdate(userId, envelope, expected, now);
        if (updated == 0) {
            audit.warn("vault put conflict reason=stale-version user={} expected={}", userId, expected);
            throw new VaultVersionConflict();
        }
        audit.info("vault updated user={} version={}", userId, expected + 1);
        return new VaultResult(expected + 1, now);
    }

    @Transactional
    public void delete(UUID userId) {
        vaults.deleteById(userId);
        audit.info("vault deleted user={}", userId);
    }
}
