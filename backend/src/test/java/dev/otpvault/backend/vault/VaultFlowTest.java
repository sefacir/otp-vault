package dev.otpvault.backend.vault;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;

import dev.otpvault.backend.auth.RateLimiter;
import dev.otpvault.backend.auth.RefreshTokenRepository;
import dev.otpvault.backend.auth.UserRepository;
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
class VaultFlowTest {

    @Autowired
    private MockMvc mvc;

    @Autowired
    private VaultRepository vaults;

    @Autowired
    private UserRepository users;

    @Autowired
    private RefreshTokenRepository refreshTokens;

    @Autowired
    private RateLimiter rateLimiter;

    @BeforeEach
    void reset() {
        vaults.deleteAll();
        refreshTokens.deleteAll();
        users.deleteAll();
        rateLimiter.reset();
    }

    private String tokenFor(String email) throws Exception {
        mvc.perform(post("/auth/register")
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"email\":\"" + email + "\",\"password\":\"password123\"}"));
        String body = mvc.perform(post("/auth/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"email\":\"" + email + "\",\"password\":\"password123\"}"))
                .andReturn().getResponse().getContentAsString();
        Matcher matcher = Pattern.compile("\"accessToken\"\\s*:\\s*\"([^\"]*)\"").matcher(body);
        assertTrue(matcher.find(), "no accessToken in " + body);
        return matcher.group(1);
    }

    private RequestBuilder putVault(String token, String json) {
        return put("/vault")
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json);
    }

    private String bodyOf(RequestBuilder request) throws Exception {
        return mvc.perform(request).andReturn().getResponse().getContentAsString();
    }

    private int statusOf(RequestBuilder request) throws Exception {
        return mvc.perform(request).andReturn().getResponse().getStatus();
    }

    @Test
    void getRequiresAuth() throws Exception {
        assertEquals(401, statusOf(get("/vault")));
    }

    @Test
    void getWithoutBackupReturns404() throws Exception {
        String token = tokenFor("v1@example.com");
        assertEquals(404, statusOf(get("/vault").header("Authorization", "Bearer " + token)));
    }

    @Test
    void putThenGetRoundTrips() throws Exception {
        String token = tokenFor("v2@example.com");

        String putBody = bodyOf(putVault(token, "{\"envelope\":\"blob-v1\"}"));
        assertTrue(putBody.contains("\"version\":1"), putBody);

        String getBody = bodyOf(get("/vault").header("Authorization", "Bearer " + token));
        assertTrue(getBody.contains("\"envelope\":\"blob-v1\""), getBody);
        assertTrue(getBody.contains("\"version\":1"), getBody);
    }

    @Test
    void updateWithMatchingVersionBumpsVersion() throws Exception {
        String token = tokenFor("v3@example.com");
        mvc.perform(putVault(token, "{\"envelope\":\"blob-v1\"}"));

        String updated = bodyOf(putVault(token, "{\"envelope\":\"blob-v2\",\"expectedVersion\":1}"));
        assertTrue(updated.contains("\"version\":2"), updated);

        String getBody = bodyOf(get("/vault").header("Authorization", "Bearer " + token));
        assertTrue(getBody.contains("\"envelope\":\"blob-v2\""), getBody);
        assertTrue(getBody.contains("\"version\":2"), getBody);
    }

    @Test
    void updateWithStaleVersionReturns409() throws Exception {
        String token = tokenFor("v4@example.com");
        mvc.perform(putVault(token, "{\"envelope\":\"blob-v1\"}"));
        mvc.perform(putVault(token, "{\"envelope\":\"blob-v2\",\"expectedVersion\":1}"));

        assertEquals(409, statusOf(putVault(token, "{\"envelope\":\"blob-v3\",\"expectedVersion\":1}")));
    }

    @Test
    void firstPutWithNonZeroVersionReturns409() throws Exception {
        String token = tokenFor("v5@example.com");
        assertEquals(409, statusOf(putVault(token, "{\"envelope\":\"blob\",\"expectedVersion\":1}")));
    }

    @Test
    void deleteRemovesBackup() throws Exception {
        String token = tokenFor("v6@example.com");
        mvc.perform(putVault(token, "{\"envelope\":\"blob-v1\"}"));

        assertEquals(204, statusOf(delete("/vault").header("Authorization", "Bearer " + token)));
        assertEquals(404, statusOf(get("/vault").header("Authorization", "Bearer " + token)));
    }

    @Test
    void vaultIsIsolatedPerUser() throws Exception {
        String alice = tokenFor("alice@example.com");
        String bob = tokenFor("bob@example.com");
        mvc.perform(putVault(alice, "{\"envelope\":\"alice-blob\"}"));

        assertEquals(404, statusOf(get("/vault").header("Authorization", "Bearer " + bob)));
    }

    @Test
    void blankEnvelopeReturns400() throws Exception {
        String token = tokenFor("v7@example.com");
        assertEquals(400, statusOf(putVault(token, "{\"envelope\":\"  \"}")));
    }

    @Test
    void oversizedEnvelopeReturns400() throws Exception {
        String token = tokenFor("v10@example.com");
        String oversized = "x".repeat(1_000_001);
        assertEquals(400, statusOf(putVault(token, "{\"envelope\":\"" + oversized + "\"}")));
        assertEquals(0, vaults.count());
    }

    @Test
    void putRequiresAuth() throws Exception {
        assertEquals(401, statusOf(put("/vault")
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"envelope\":\"blob\"}")));
        assertEquals(0, vaults.count());
    }

    @Test
    void tokenForDeletedUserStillYields404NotError() throws Exception {
        String token = tokenFor("v8@example.com");
        users.deleteAll();
        assertEquals(404, statusOf(get("/vault").header("Authorization", "Bearer " + token)));
    }

    @Test
    void rateLimitsRepeatedPut() throws Exception {
        String token = tokenFor("v11@example.com");
        int last = 0;
        for (int i = 0; i < 12; i++) {
            last = statusOf(putVault(token, "{\"envelope\":\"blob\"}"));
        }
        assertEquals(429, last);
    }
}
