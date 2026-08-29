package dev.otpvault.backend.auth;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;
import java.util.Date;
import java.util.UUID;
import javax.crypto.SecretKey;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.env.Environment;
import org.springframework.stereotype.Service;

@Service
public class JwtService {

    static final String INSECURE_DEV_SECRET = "dev-only-insecure-secret-change-me-min-32-bytes";
    private static final String ISSUER = "otp-vault";

    private final SecretKey key;
    private final Duration accessTtl;

    public JwtService(
            @Value("${otpvault.jwt.secret}") String secret,
            @Value("${otpvault.jwt.access-ttl-seconds:900}") long accessTtlSeconds,
            Environment environment) {
        if (INSECURE_DEV_SECRET.equals(secret) && environment.matchesProfiles("prod")) {
            throw new IllegalStateException("OTPVAULT_JWT_SECRET must be set outside development");
        }
        this.key = Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8));
        this.accessTtl = Duration.ofSeconds(accessTtlSeconds);
    }

    public String issueAccessToken(UUID userId) {
        Instant now = Instant.now();
        return Jwts.builder()
                .id(UUID.randomUUID().toString())
                .issuer(ISSUER)
                .subject(userId.toString())
                .issuedAt(Date.from(now))
                .expiration(Date.from(now.plus(accessTtl)))
                .signWith(key)
                .compact();
    }

    public long accessTtlSeconds() {
        return accessTtl.toSeconds();
    }

    public UUID parseUserId(String token) {
        Claims claims = Jwts.parser()
                .verifyWith(key)
                .requireIssuer(ISSUER)
                .build()
                .parseSignedClaims(token)
                .getPayload();
        return UUID.fromString(claims.getSubject());
    }
}
