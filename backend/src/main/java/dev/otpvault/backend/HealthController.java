package dev.otpvault.backend;

import java.time.Instant;
import java.util.Map;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
class HealthController {

    @GetMapping("/health")
    Map<String, Object> health() {
        return Map.of(
                "status", "ok",
                "service", "otp-vault-backend",
                "time", Instant.now().toString());
    }
}
