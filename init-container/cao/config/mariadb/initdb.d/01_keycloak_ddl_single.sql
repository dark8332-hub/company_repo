create or replace table keycloak.USER_MFA(
	id varchar(255) default UUID(),
	user_id varchar(255),
	credential_code varchar(255),
	expire_date timestamp,
	repeat_count int default 0,
	created_timestamp timestamp default now(),
	PRIMARY KEY(id)
);

create or replace table keycloak.USER_IDENTITY_VERIFICATION(
    id                varchar(255) default UUID(),
    credential_code   varchar(255),
    expire_date       timestamp,
    repeat_count      int          default 0,
    auth_type         varchar(255),
    channel_type              varchar(255),
    channel_type_value             varchar(255),
    updated_timestamp timestamp,
    created_timestamp timestamp default now(),
    PRIMARY KEY (id)
);

create or replace table keycloak.USER_TEMPORARY_AUTH_COOKIE(
    id                 varchar(255) default UUID(),
    value              varchar(255),
    expire_date        timestamp,
    auth_type          varchar(255),
    created_timestamp  timestamp    default now(),
    PRIMARY KEY (id)
);

ALTER TABLE keycloak.USER_MFA CHANGE expire_date expire_date timestamp NOT NULL DEFAULT current_timestamp;

ALTER TABLE keycloak.USER_IDENTITY_VERIFICATION CHANGE expire_date expire_date timestamp NOT NULL DEFAULT current_timestamp;

ALTER TABLE keycloak.USER_TEMPORARY_AUTH_COOKIE CHANGE expire_date expire_date timestamp NOT NULL DEFAULT current_timestamp;
