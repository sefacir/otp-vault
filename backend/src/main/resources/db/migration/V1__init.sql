create table app_user (
    id                    uuid                        not null,
    email                 varchar(255)                not null,
    password_hash         varchar(255)                not null,
    created_at            timestamp(6) with time zone not null,
    failed_login_attempts integer                     not null,
    locked_until          timestamp(6) with time zone,
    constraint app_user_pkey primary key (id),
    constraint app_user_email_key unique (email)
);

create table refresh_token (
    id         uuid                        not null,
    user_id    uuid                        not null,
    token_hash varchar(64)                 not null,
    expires_at timestamp(6) with time zone not null,
    revoked    boolean                     not null,
    constraint refresh_token_pkey primary key (id),
    constraint refresh_token_token_hash_key unique (token_hash)
);

create index idx_refresh_token_user on refresh_token (user_id);

create table vault (
    user_id    uuid                        not null,
    envelope   text                        not null,
    version    integer                     not null,
    updated_at timestamp(6) with time zone not null,
    constraint vault_pkey primary key (user_id)
);
