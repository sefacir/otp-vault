package dev.otpvault.backend.auth;

import java.util.Map;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

@RestControllerAdvice
class AuthExceptionHandler {

    @ExceptionHandler(EmailAlreadyRegistered.class)
    ResponseEntity<Map<String, String>> handleEmailTaken() {
        return ResponseEntity.status(HttpStatus.CONFLICT)
                .body(Map.of("error", "email_already_registered"));
    }

    @ExceptionHandler(InvalidCredentials.class)
    ResponseEntity<Map<String, String>> handleInvalidCredentials() {
        return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                .body(Map.of("error", "invalid_credentials"));
    }

    @ExceptionHandler(InvalidRefreshToken.class)
    ResponseEntity<Map<String, String>> handleInvalidRefresh() {
        return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                .body(Map.of("error", "invalid_refresh_token"));
    }

    @ExceptionHandler(AccountLocked.class)
    ResponseEntity<Map<String, String>> handleLocked() {
        return ResponseEntity.status(HttpStatus.LOCKED)
                .body(Map.of("error", "account_locked"));
    }

    @ExceptionHandler(RateLimited.class)
    ResponseEntity<Map<String, String>> handleRateLimited() {
        return ResponseEntity.status(HttpStatus.TOO_MANY_REQUESTS)
                .body(Map.of("error", "rate_limited"));
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    ResponseEntity<Map<String, String>> handleValidation(MethodArgumentNotValidException ex) {
        String detail = ex.getBindingResult().getFieldErrors().stream()
                .findFirst()
                .map(fe -> fe.getField() + " " + fe.getDefaultMessage())
                .orElse("invalid request");
        return ResponseEntity.badRequest()
                .body(Map.of("error", "validation_failed", "detail", detail));
    }

    @ExceptionHandler(HttpMessageNotReadableException.class)
    ResponseEntity<Map<String, String>> handleUnreadable() {
        return ResponseEntity.badRequest()
                .body(Map.of("error", "malformed_request"));
    }

    @ExceptionHandler(DataIntegrityViolationException.class)
    ResponseEntity<Map<String, String>> handleDataIntegrity() {
        return ResponseEntity.status(HttpStatus.CONFLICT)
                .body(Map.of("error", "conflict"));
    }
}
