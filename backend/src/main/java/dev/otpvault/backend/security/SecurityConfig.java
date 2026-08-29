package dev.otpvault.backend.security;

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
    SecurityFilterChain filterChain(HttpSecurity http, JwtAuthenticationFilter jwtFilter) {
        try {
            return http
                    .csrf(csrf -> csrf.disable())
                    .sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                    .authorizeHttpRequests(auth -> auth
                            .requestMatchers("/auth/register", "/auth/login", "/auth/refresh").permitAll()
                            .requestMatchers("/health", "/actuator/health/**").permitAll()
                            .requestMatchers("/actuator/**").denyAll()
                            .anyRequest().authenticated())
                    .exceptionHandling(ex -> ex.authenticationEntryPoint(
                            new HttpStatusEntryPoint(HttpStatus.UNAUTHORIZED)))
                    .addFilterBefore(jwtFilter, UsernamePasswordAuthenticationFilter.class)
                    .build();
        } catch (Exception e) {
            throw new IllegalStateException("Failed to build security filter chain", e);
        }
    }

    @Bean
    PasswordEncoder passwordEncoder() {
        return Argon2PasswordEncoder.defaultsForSpringSecurity_v5_8();
    }
}
