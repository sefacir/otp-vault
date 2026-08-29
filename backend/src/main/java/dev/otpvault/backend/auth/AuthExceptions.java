package dev.otpvault.backend.auth;

import java.time.Instant;

class EmailAlreadyRegistered extends RuntimeException {
}

class InvalidCredentials extends RuntimeException {
}

class InvalidRefreshToken extends RuntimeException {
}

class AccountLocked extends RuntimeException {

    final Instant until;

    AccountLocked(Instant until) {
        this.until = until;
    }
}

class RateLimited extends RuntimeException {
}
