package dev.otpvault.backend.auth;

import dev.otpvault.backend.auth.dto.LoginRequest;
import dev.otpvault.backend.auth.dto.RefreshRequest;
import dev.otpvault.backend.auth.dto.RegisterRequest;
import dev.otpvault.backend.auth.dto.TokenResponse;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import java.util.Map;
import org.springframework.http.HttpStatus;
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
        enforceLimit("register", request);
        authService.register(body.email(), body.password());
        return Map.of("status", "registered");
    }

    @PostMapping("/login")
    TokenResponse login(@Valid @RequestBody LoginRequest body, HttpServletRequest request) {
        enforceLimit("login", request);
        return authService.login(body.email(), body.password());
    }

    @PostMapping("/refresh")
    TokenResponse refresh(@Valid @RequestBody RefreshRequest body) {
        return authService.refresh(body.refreshToken());
    }

    @GetMapping("/me")
    Map<String, String> me(@AuthenticationPrincipal String userId) {
        return Map.of("userId", userId);
    }

    private void enforceLimit(String action, HttpServletRequest request) {
        if (!rateLimiter.tryAcquire(action + ":" + request.getRemoteAddr())) {
            throw new RateLimited();
        }
    }
}
