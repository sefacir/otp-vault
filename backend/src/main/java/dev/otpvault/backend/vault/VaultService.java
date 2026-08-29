package dev.otpvault.backend.vault;

import dev.otpvault.backend.vault.dto.VaultResponse;
import java.time.Instant;
import java.util.UUID;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class VaultService {

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
                throw new VaultVersionConflict();
            }
            try {
                vaults.save(new Vault(userId, envelope, now));
            } catch (DataIntegrityViolationException concurrentCreate) {
                throw new VaultVersionConflict();
            }
            return new VaultResult(1, now);
        }

        int updated = vaults.applyUpdate(userId, envelope, expected, now);
        if (updated == 0) {
            throw new VaultVersionConflict();
        }
        return new VaultResult(expected + 1, now);
    }

    @Transactional
    public void delete(UUID userId) {
        vaults.deleteById(userId);
    }
}
