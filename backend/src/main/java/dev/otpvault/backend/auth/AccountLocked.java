package dev.otpvault.backend.auth;

import java.time.Instant;

class AccountLocked extends RuntimeException {

    private static final long serialVersionUID = 1L;

    final Instant until;

    AccountLocked(Instant until) {
        this.until = until;
    }
}
