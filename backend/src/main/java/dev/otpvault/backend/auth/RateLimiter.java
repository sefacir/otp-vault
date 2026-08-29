package dev.otpvault.backend.auth;

import java.time.Duration;
import java.time.Instant;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Component
public class RateLimiter {

    private record Window(Instant resetAt, int count) {
    }

    private final ConcurrentHashMap<String, Window> windows = new ConcurrentHashMap<>();
    private final int maxRequests = 10;
    private final Duration window = Duration.ofSeconds(60);

    public boolean tryAcquire(String key) {
        Instant now = Instant.now();
        Window updated = windows.compute(key, (ignored, current) -> {
            if (current == null || now.isAfter(current.resetAt())) {
                return new Window(now.plus(window), 1);
            }
            return new Window(current.resetAt(), current.count() + 1);
        });
        return updated.count() <= maxRequests;
    }

    @Scheduled(fixedDelay = 300_000L)
    void sweepExpired() {
        Instant now = Instant.now();
        windows.entrySet().removeIf(entry -> now.isAfter(entry.getValue().resetAt()));
    }

    public void reset() {
        windows.clear();
    }
}
