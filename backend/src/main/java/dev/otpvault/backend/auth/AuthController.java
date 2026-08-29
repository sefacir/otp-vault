package dev.otpvault.backend.auth;

import dev.otpvault.backend.auth.dto.LoginRequest;
import dev.otpvault.backend.auth.dto.RefreshRequest;
import dev.otpvault.backend.auth.dto.RegisterRequest;
import dev.otpvault.backend.auth.dto.TokenResponse;
import dev.otpvault.backend.auth.JwtService.AccessTokenClaims;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/auth")
class AuthController {

    private final AuthService authService;
    private final RateLimiter rateLimiter;

    AuthController(AuthService authService, RateLimiter rateLimiter) {
        this.authService = authService;
        this.rateLimiter = rateLimiter;
    }

    @PostMapping("/register")
    @ResponseStatus(HttpStatus.CREATED)
    Map<String, String> register(@Valid @RequestBody RegisterRequest body, HttpServletRequest request) {
        enforceLimit("register", request, body.email());
        authService.register(body.email(), body.password());
        return Map.of("status", "registered");
    }

    @PostMapping("/login")
    TokenResponse login(@Valid @RequestBody LoginRequest body, HttpServletRequest request) {
        enforceLimit("login", request, body.email());
        return authService.login(body.email(), body.password());
    }

    @PostMapping("/refresh")
    TokenResponse refresh(@Valid @RequestBody RefreshRequest body, HttpServletRequest request) {
        if (!rateLimiter.tryAcquire("refresh:ip:" + request.getRemoteAddr())) {
            throw new RateLimited();
        }
        return authService.refresh(body.refreshToken());
    }

    @GetMapping("/me")
    Map<String, String> me(@AuthenticationPrincipal String userId) {
        return Map.of("userId", userId);
    }

    @PostMapping("/logout")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    void logout(Authentication authentication) {
        AccessTokenClaims claims = (AccessTokenClaims) authentication.getCredentials();
        authService.logout(
                UUID.fromString((String) authentication.getPrincipal()),
                claims.jti(),
                claims.expiresAt());
    }

    private void enforceLimit(String action, HttpServletRequest request, String identifier) {
        boolean ipAllowed = rateLimiter.tryAcquire(action + ":ip:" + request.getRemoteAddr());
        boolean identifierAllowed = rateLimiter.tryAcquire(
                action + ":id:" + identifier.trim().toLowerCase(Locale.ROOT));
        if (!ipAllowed || !identifierAllowed) {
            throw new RateLimited();
        }
    }
}
