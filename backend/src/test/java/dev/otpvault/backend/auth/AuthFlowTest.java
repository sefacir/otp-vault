package dev.otpvault.backend.auth;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.UUID;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.RequestBuilder;

@SpringBootTest
@AutoConfigureMockMvc
class AuthFlowTest {

    @Autowired
    private MockMvc mvc;

    @Autowired
    private UserRepository users;

    @Autowired
    private RefreshTokenRepository refreshTokens;

    @Autowired
    private RateLimiter rateLimiter;

    @Autowired
    private TokenDenylist denylist;

    @BeforeEach
    void reset() {
        refreshTokens.deleteAll();
        users.deleteAll();
        rateLimiter.reset();
        denylist.reset();
    }

    private RequestBuilder registerRequest(String email, String password) {
        return post("/auth/register")
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"email\":\"" + email + "\",\"password\":\"" + password + "\"}");
    }

    private RequestBuilder loginRequest(String email, String password) {
        return post("/auth/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"email\":\"" + email + "\",\"password\":\"" + password + "\"}");
    }

    private RequestBuilder refreshRequest(String token) {
        return post("/auth/refresh")
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"refreshToken\":\"" + token + "\"}");
    }

    private int status(RequestBuilder request) throws Exception {
        return mvc.perform(request).andReturn().getResponse().getStatus();
    }

    private String field(RequestBuilder request, String name) throws Exception {
        String body = mvc.perform(request).andReturn().getResponse().getContentAsString();
        Matcher matcher = Pattern.compile("\"" + name + "\"\\s*:\\s*\"([^\"]*)\"").matcher(body);
        if (!matcher.find()) {
            throw new AssertionError("no \"" + name + "\" field in response: " + body);
        }
        return matcher.group(1);
    }

    @Test
    void registerLoginAndReadMe() throws Exception {
        assertEquals(201, status(registerRequest("a@example.com", "password123")));

        String access = field(loginRequest("a@example.com", "password123"), "accessToken");

        assertEquals(200, mvc.perform(get("/auth/me").header("Authorization", "Bearer " + access))
                .andReturn().getResponse().getStatus());
    }

    @Test
    void rejectsDuplicateEmail() throws Exception {
        status(registerRequest("dup@example.com", "password123"));
        assertEquals(409, status(registerRequest("dup@example.com", "password123")));
    }

    @Test
    void rejectsInvalidRegistration() throws Exception {
        assertEquals(400, status(registerRequest("not-an-email", "password123")));
        assertEquals(400, status(registerRequest("b@example.com", "short")));
    }

    @Test
    void meRequiresToken() throws Exception {
        assertEquals(401, mvc.perform(get("/auth/me")).andReturn().getResponse().getStatus());
    }

    @Test
    void meRejectsGarbageToken() throws Exception {
        assertEquals(401, mvc.perform(get("/auth/me").header("Authorization", "Bearer not.a.jwt"))
                .andReturn().getResponse().getStatus());
    }

    @Test
    void locksAccountAfterFiveFailures() throws Exception {
        status(registerRequest("lock@example.com", "password123"));
        for (int i = 0; i < 5; i++) {
            assertEquals(401, status(loginRequest("lock@example.com", "wrongpass")));
        }
        assertEquals(423, status(loginRequest("lock@example.com", "password123")));
    }

    @Test
    void wrongPasswordLooksTheSameForUnknownEmail() throws Exception {
        status(registerRequest("known@example.com", "password123"));
        assertEquals(401, status(loginRequest("known@example.com", "wrongpass")));
        assertEquals(401, status(loginRequest("nobody@example.com", "wrongpass")));
    }

    @Test
    void rotatesRefreshTokenAndDetectsReuse() throws Exception {
        status(registerRequest("rot@example.com", "password123"));
        String original = field(loginRequest("rot@example.com", "password123"), "refreshToken");

        String rotated = field(refreshRequest(original), "refreshToken");
        assertEquals(401, status(refreshRequest(original)));
        assertEquals(401, status(refreshRequest(rotated)));
    }

    @Test
    void successfulLoginResetsFailureCount() throws Exception {
        status(registerRequest("reset@example.com", "password123"));
        for (int i = 0; i < 3; i++) {
            assertEquals(401, status(loginRequest("reset@example.com", "wrongpass")));
        }
        assertEquals(200, status(loginRequest("reset@example.com", "password123")));
        for (int i = 0; i < 4; i++) {
            assertEquals(401, status(loginRequest("reset@example.com", "wrongpass")));
        }
    }

    @Test
    void purgeQueryRemovesExpiredAndRevokedTokens() {
        UUID user = UUID.randomUUID();
        refreshTokens.save(new RefreshToken(user, "hash-expired", Instant.now().minus(1, ChronoUnit.DAYS)));
        RefreshToken revoked = new RefreshToken(user, "hash-revoked", Instant.now().plus(1, ChronoUnit.DAYS));
        revoked.revoke();
        refreshTokens.save(revoked);
        RefreshToken live = refreshTokens.save(
                new RefreshToken(user, "hash-live", Instant.now().plus(1, ChronoUnit.DAYS)));

        int removed = refreshTokens.deleteExpiredOrRevoked(Instant.now());

        assertEquals(2, removed);
        assertEquals(1, refreshTokens.count());
        assertEquals(live.getUserId(), refreshTokens.findAll().get(0).getUserId());
    }

    @Test
    void logoutRevokesAccessAndRefreshTokens() throws Exception {
        status(registerRequest("out@example.com", "password123"));
        String body = mvc.perform(loginRequest("out@example.com", "password123"))
                .andReturn().getResponse().getContentAsString();
        String access = matchField(body, "accessToken");
        String refresh = matchField(body, "refreshToken");

        assertEquals(200, mvc.perform(get("/auth/me").header("Authorization", "Bearer " + access))
                .andReturn().getResponse().getStatus());

        assertEquals(204, mvc.perform(post("/auth/logout").header("Authorization", "Bearer " + access))
                .andReturn().getResponse().getStatus());

        assertEquals(401, mvc.perform(get("/auth/me").header("Authorization", "Bearer " + access))
                .andReturn().getResponse().getStatus());
        assertEquals(401, status(refreshRequest(refresh)));
    }

    @Test
    void logoutRequiresAuthentication() throws Exception {
        assertEquals(401, mvc.perform(post("/auth/logout")).andReturn().getResponse().getStatus());
    }

    @Test
    void rejectsMalformedJsonBody() throws Exception {
        assertEquals(400, mvc.perform(post("/auth/register")
                .contentType(MediaType.APPLICATION_JSON)
                .content("{not json"))
                .andReturn().getResponse().getStatus());
    }

    private String matchField(String body, String name) {
        Matcher matcher = Pattern.compile("\"" + name + "\"\\s*:\\s*\"([^\"]*)\"").matcher(body);
        if (!matcher.find()) {
            throw new AssertionError("no \"" + name + "\" field in response: " + body);
        }
        return matcher.group(1);
    }

    @Test
    void rateLimitsRepeatedRegistration() throws Exception {
        int last = 0;
        for (int i = 0; i < 12; i++) {
            last = status(registerRequest("rl" + i + "@example.com", "password123"));
        }
        assertEquals(429, last);
    }
}
