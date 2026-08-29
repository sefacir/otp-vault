package dev.otpvault.backend.auth;

import dev.otpvault.backend.auth.dto.TokenResponse;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.HexFormat;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AuthService {

    private static final Logger audit = LoggerFactory.getLogger("audit.auth");
    private static final int MAX_FAILED_ATTEMPTS = 5;
    private static final Duration LOCK_DURATION = Duration.ofMinutes(15);
    private static final Duration REFRESH_TTL = Duration.ofDays(7);

    private final UserRepository users;
    private final RefreshTokenRepository refreshTokens;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;
    private final SecureRandom random = new SecureRandom();
    private final String timingHash;

    public AuthService(
            UserRepository users,
            RefreshTokenRepository refreshTokens,
            PasswordEncoder passwordEncoder,
            JwtService jwtService) {
        this.users = users;
        this.refreshTokens = refreshTokens;
        this.passwordEncoder = passwordEncoder;
        this.jwtService = jwtService;
        this.timingHash = passwordEncoder.encode("timing-equalizer-not-a-real-password");
    }

    @Transactional
    public void register(String email, String password) {
        String normalized = normalize(email);
        if (users.existsByEmail(normalized)) {
            throw new EmailAlreadyRegistered();
        }
        AppUser user = users.save(new AppUser(normalized, passwordEncoder.encode(password)));
        audit.info("register success user={}", user.getId());
    }

    public TokenResponse login(String email, String password) {
        AppUser user = users.findByEmail(normalize(email)).orElse(null);
        if (user == null) {
            passwordEncoder.matches(password, timingHash);
            audit.warn("login failed reason=unknown-email");
            throw new InvalidCredentials();
        }

        Instant now = Instant.now();
        if (user.isLocked(now)) {
            audit.warn("login blocked reason=locked user={}", user.getId());
            throw new AccountLocked(user.getLockedUntil());
        }

        if (!passwordEncoder.matches(password, user.getPasswordHash())) {
            int attempts = user.getFailedLoginAttempts() + 1;
            if (attempts >= MAX_FAILED_ATTEMPTS) {
                users.lockUntil(user.getId(), now.plus(LOCK_DURATION));
                audit.warn("account locked user={} attempts={}", user.getId(), attempts);
            } else {
                users.incrementFailedAttempts(user.getId());
            }
            audit.warn("login failed reason=bad-password user={} attempts={}", user.getId(), attempts);
            throw new InvalidCredentials();
        }

        if (user.getFailedLoginAttempts() > 0 || user.getLockedUntil() != null) {
            users.clearLoginFailures(user.getId());
        }
        audit.info("login success user={}", user.getId());
        return issueTokens(user);
    }

    public TokenResponse refresh(String rawToken) {
        RefreshToken stored = refreshTokens.findByTokenHash(sha256(rawToken))
                .orElseThrow(InvalidRefreshToken::new);

        Instant now = Instant.now();
        if (stored.isRevoked()) {
            refreshTokens.revokeAllForUser(stored.getUserId());
            audit.warn("refresh-token reuse detected, family revoked user={}", stored.getUserId());
            throw new InvalidRefreshToken();
        }
        if (stored.isExpired(now)) {
            throw new InvalidRefreshToken();
        }

        AppUser user = users.findById(stored.getUserId()).orElseThrow(InvalidRefreshToken::new);
        if (user.isLocked(now)) {
            audit.warn("refresh blocked reason=locked user={}", user.getId());
            throw new AccountLocked(user.getLockedUntil());
        }

        stored.revoke();
        refreshTokens.save(stored);
        audit.info("refresh success user={}", user.getId());
        return issueTokens(user);
    }

    private TokenResponse issueTokens(AppUser user) {
        String access = jwtService.issueAccessToken(user.getId());
        String rawRefresh = randomToken();
        refreshTokens.save(new RefreshToken(
                user.getId(),
                sha256(rawRefresh),
                Instant.now().plus(REFRESH_TTL)));
        return new TokenResponse(access, rawRefresh, jwtService.accessTtlSeconds());
    }

    private String normalize(String email) {
        return email.trim().toLowerCase();
    }

    private String randomToken() {
        byte[] bytes = new byte[32];
        random.nextBytes(bytes);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }

    private String sha256(String value) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            return HexFormat.of().formatHex(digest.digest(value.getBytes(StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 unavailable", e);
        }
    }
}
