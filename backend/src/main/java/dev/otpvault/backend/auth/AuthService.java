package dev.otpvault.backend.auth;

import dev.otpvault.backend.auth.dto.TokenResponse;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.HexFormat;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AuthService {

    private static final int MAX_FAILED_ATTEMPTS = 5;
    private static final Duration LOCK_DURATION = Duration.ofMinutes(15);
    private static final Duration REFRESH_TTL = Duration.ofDays(7);

    private final UserRepository users;
    private final RefreshTokenRepository refreshTokens;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;
    private final SecureRandom random = new SecureRandom();

    public AuthService(
            UserRepository users,
            RefreshTokenRepository refreshTokens,
            PasswordEncoder passwordEncoder,
            JwtService jwtService) {
        this.users = users;
        this.refreshTokens = refreshTokens;
        this.passwordEncoder = passwordEncoder;
        this.jwtService = jwtService;
    }

    @Transactional
    public void register(String email, String password) {
        String normalized = normalize(email);
        if (users.existsByEmail(normalized)) {
            throw new EmailAlreadyRegistered();
        }
        users.save(new AppUser(normalized, passwordEncoder.encode(password)));
    }

    public TokenResponse login(String email, String password) {
        AppUser user = users.findByEmail(normalize(email)).orElseThrow(InvalidCredentials::new);

        Instant now = Instant.now();
        if (user.isLocked(now)) {
            throw new AccountLocked(user.getLockedUntil());
        }

        if (!passwordEncoder.matches(password, user.getPasswordHash())) {
            user.registerFailedLogin(MAX_FAILED_ATTEMPTS, LOCK_DURATION, now);
            users.save(user);
            throw new InvalidCredentials();
        }

        user.registerSuccessfulLogin();
        users.save(user);
        return issueTokens(user);
    }

    @Transactional
    public TokenResponse refresh(String rawToken) {
        RefreshToken stored = refreshTokens.findByTokenHash(sha256(rawToken))
                .orElseThrow(InvalidRefreshToken::new);
        if (!stored.isUsable(Instant.now())) {
            throw new InvalidRefreshToken();
        }
        stored.revoke();
        refreshTokens.save(stored);

        AppUser user = users.findById(stored.getUserId()).orElseThrow(InvalidRefreshToken::new);
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
            return HexFormat.of().formatHex(digest.digest(value.getBytes(java.nio.charset.StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);
        }
    }
}
