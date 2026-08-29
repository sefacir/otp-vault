package dev.otpvault.backend.security;

import java.time.Duration;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpStatus;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.argon2.Argon2PasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.HttpStatusEntryPoint;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;

@Configuration
public class SecurityConfig {

    @Bean
    SecurityFilterChain filterChain(
            HttpSecurity http,
            JwtAuthenticationFilter jwtFilter,
            @Value("${otpvault.security.require-https:false}") boolean requireHttps) {
        try {
            http
                    .csrf(csrf -> csrf.disable())
                    .sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                    .headers(headers -> headers.httpStrictTransportSecurity(hsts -> hsts
                            .includeSubDomains(true)
                            .maxAgeInSeconds(Duration.ofDays(365).toSeconds())))
                    .authorizeHttpRequests(auth -> auth
                            .requestMatchers("/auth/register", "/auth/login", "/auth/refresh").permitAll()
                            .requestMatchers("/health", "/actuator/health/**").permitAll()
                            .requestMatchers("/actuator/**").denyAll()
                            .anyRequest().authenticated())
                    .exceptionHandling(ex -> ex.authenticationEntryPoint(
                            new HttpStatusEntryPoint(HttpStatus.UNAUTHORIZED)))
                    .addFilterBefore(jwtFilter, UsernamePasswordAuthenticationFilter.class);

            if (requireHttps) {
                http.requiresChannel(channel -> channel.anyRequest().requiresSecure());
            }
            return http.build();
        } catch (Exception e) {
            throw new IllegalStateException("Failed to build security filter chain", e);
        }
    }

    @Bean
    PasswordEncoder passwordEncoder() {
        return Argon2PasswordEncoder.defaultsForSpringSecurity_v5_8();
    }
}
