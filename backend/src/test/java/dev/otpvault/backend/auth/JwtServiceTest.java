package dev.otpvault.backend.auth;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class JwtServiceTest {

    private static final String SECRET = "unit-test-secret-that-is-well-over-32-bytes-long";

    private JwtService service(long ttlSeconds) {
        return new JwtService(SECRET, ttlSeconds);
    }

    @Test
    void issuesAndParsesToken() {
        UUID userId = UUID.randomUUID();
        JwtService jwt = service(900);
        assertEquals(userId, jwt.parseUserId(jwt.issueAccessToken(userId)));
    }

    @Test
    void parseExposesJtiAndExpiry() {
        UUID userId = UUID.randomUUID();
        JwtService jwt = service(900);
        JwtService.AccessTokenClaims claims = jwt.parse(jwt.issueAccessToken(userId));
        assertEquals(userId, claims.userId());
        assertNotNull(claims.jti());
        assertTrue(claims.expiresAt().isAfter(Instant.now()));
    }

    @Test
    void rejectsTokenSignedWithAnotherKey() {
        String token = service(900).issueAccessToken(UUID.randomUUID());
        JwtService other = new JwtService("a-totally-different-secret-also-over-32-bytes", 900);
        assertThrows(JwtException.class, () -> other.parseUserId(token));
    }

    @Test
    void rejectsTamperedToken() {
        String token = service(900).issueAccessToken(UUID.randomUUID());
        String tampered = token.substring(0, token.length() - 2) + (token.endsWith("A") ? "B" : "A");
        assertThrows(JwtException.class, () -> service(900).parseUserId(tampered));
    }

    @Test
    void rejectsExpiredToken() {
        JwtService jwt = service(-1);
        String token = jwt.issueAccessToken(UUID.randomUUID());
        assertThrows(JwtException.class, () -> jwt.parseUserId(token));
    }

    @Test
    void rejectsTokenWithWrongIssuer() {
        String forged = Jwts.builder()
                .issuer("evil")
                .subject(UUID.randomUUID().toString())
                .signWith(Keys.hmacShaKeyFor(SECRET.getBytes(StandardCharsets.UTF_8)))
                .compact();
        assertThrows(JwtException.class, () -> service(900).parseUserId(forged));
    }

    @Test
    void rejectsBlankSecret() {
        assertThrows(IllegalStateException.class, () -> new JwtService("", 900));
        assertThrows(IllegalStateException.class, () -> new JwtService("   ", 900));
    }

    @Test
    void rejectsShortSecret() {
        assertThrows(IllegalStateException.class, () -> new JwtService("too-short", 900));
    }
}
