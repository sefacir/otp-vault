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
import org.springframework.stereotype.Service;

@Service
public class JwtService {

    private static final String ISSUER = "otp-vault";
    private static final int MIN_SECRET_BYTES = 32;

    private final SecretKey key;
    private final Duration accessTtl;

    public JwtService(
            @Value("${otpvault.jwt.secret}") String secret,
            @Value("${otpvault.jwt.access-ttl-seconds:900}") long accessTtlSeconds) {
        if (secret == null || secret.isBlank()) {
            throw new IllegalStateException("OTPVAULT_JWT_SECRET must be set");
        }
        if (secret.getBytes(StandardCharsets.UTF_8).length < MIN_SECRET_BYTES) {
            throw new IllegalStateException("OTPVAULT_JWT_SECRET must be at least 32 bytes");
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
        return parse(token).userId();
    }

    public AccessTokenClaims parse(String token) {
        Claims claims = Jwts.parser()
                .verifyWith(key)
                .requireIssuer(ISSUER)
                .build()
                .parseSignedClaims(token)
                .getPayload();
        return new AccessTokenClaims(
                UUID.fromString(claims.getSubject()),
                claims.getId(),
                claims.getExpiration().toInstant());
    }

    public record AccessTokenClaims(UUID userId, String jti, Instant expiresAt) {}
}
