package dev.otpvault.backend.vault;

import dev.otpvault.backend.auth.RateLimited;
import dev.otpvault.backend.auth.RateLimiter;
import dev.otpvault.backend.vault.dto.PutVaultRequest;
import dev.otpvault.backend.vault.dto.VaultResponse;
import jakarta.validation.Valid;
import java.util.Map;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/vault")
class VaultController {

    private final VaultService vaultService;
    private final RateLimiter rateLimiter;

    VaultController(VaultService vaultService, RateLimiter rateLimiter) {
        this.vaultService = vaultService;
        this.rateLimiter = rateLimiter;
    }

    @GetMapping
    VaultResponse get(@AuthenticationPrincipal String userId) {
        return vaultService.get(UUID.fromString(userId));
    }

    @PutMapping
    Map<String, Object> put(@AuthenticationPrincipal String userId, @Valid @RequestBody PutVaultRequest body) {
        if (!rateLimiter.tryAcquire("vault-put:" + userId)) {
            throw new RateLimited();
        }
        VaultResult result = vaultService.save(UUID.fromString(userId), body.envelope(), body.expectedVersion());
        return Map.of("version", result.version(), "updatedAt", result.updatedAt().toString());
    }

    @DeleteMapping
    @ResponseStatus(HttpStatus.NO_CONTENT)
    void delete(@AuthenticationPrincipal String userId) {
        vaultService.delete(UUID.fromString(userId));
    }
}
