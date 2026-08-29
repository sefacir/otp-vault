package dev.otpvault.backend.auth;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import java.nio.charset.StandardCharsets;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.mock.env.MockEnvironment;

class JwtServiceTest {

    private static final String SECRET = "unit-test-secret-that-is-well-over-32-bytes-long";

    private JwtService service(long ttlSeconds) {
        return new JwtService(SECRET, ttlSeconds, new MockEnvironment());
    }

    @Test
    void issuesAndParsesToken() {
        UUID userId = UUID.randomUUID();
        JwtService jwt = service(900);
        assertEquals(userId, jwt.parseUserId(jwt.issueAccessToken(userId)));
    }

    @Test
    void rejectsTokenSignedWithAnotherKey() {
        String token = service(900).issueAccessToken(UUID.randomUUID());
        JwtService other = new JwtService("a-totally-different-secret-also-over-32-bytes", 900, new MockEnvironment());
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
    void failsFastWithDevSecretUnderProdProfile() {
        MockEnvironment prod = new MockEnvironment();
        prod.setActiveProfiles("prod");
        assertThrows(IllegalStateException.class,
                () -> new JwtService(JwtService.INSECURE_DEV_SECRET, 900, prod));
    }
}
